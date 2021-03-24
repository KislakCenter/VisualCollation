require 'zip'
require 'securerandom'

class ExportController < ApplicationController

  before_action :authenticate!
  before_action :set_project, only: [:show]

  # GET /projects/:id/export/:format
  def show
    # Zip all DIY images and provide the link to download the file
    begin
      @zipFilePath = nil
      images       = []
      current_user.images.all.each do |image|
        if image.projectIDs.include? @project.id.to_s
          images.push(image)
        end
      end
      if !images.empty?
        basePath    = "#{Rails.root}/public/uploads/"
        zipFilename = "#{basePath}#{@project.id.to_s}_images.zip"
        File.delete(zipFilename) if File.exist?(zipFilename)
        ::Zip::File.open(zipFilename, Zip::File::CREATE) do |zipFile|
          images.each do |image|
            fileExtension = image.metadata['mime_type'].split('/')[1]
            filenameOnly  = image.filename.rpartition(".")[0]
            zipFile.add("#{filenameOnly}_#{image.fileID}.#{fileExtension}", "#{basePath}#{image.fileID}")
          end
        end
        @zipFilePath = "#{@base_api_url}/images/zip/#{@project.id.to_s}"
      end
    rescue Exception => e
    end

    begin
      exportData = buildDotModel(@project)
      xml        = Nokogiri::XML(exportData)
      schema     = Nokogiri::XML::RelaxNG(File.open("public/viscoll-datamodel2.0.rng"))
      errors     = schema.validate(xml)

      if errors.empty?
        case @format
        when "xml"
          render json: { data: exportData, type: @format, Images: { exportedImages: @zipFilePath ? @zipFilePath : false } }, status: :ok and return
        when "json"
          @data = buildJSON(@project)
          render :'exports/show', status: :ok and return
        when 'svg'
          collation_file = 'collation.css'
          config_xml     = %Q{<config><css xml:id="css">#{collation_file}</css></config>}
          job_response   = process_pipeline 'viscoll2svg', xml.to_xml, config_xml
          outfile        = write_zip_file job_response, 'svg'
          @zipFilePath   = "#{@base_api_url}/transformations/zip/#{@project.id}-svg"
          exportData     = []
          Zip::File.open(outfile) do |zip_file|
            zip_file.each do |entry|
              if File.extname(entry.name) === '.svg'
                exportData << entry.get_input_stream.read
              end
            end
          end

          render json: { data: exportData, type: @format, Images: { exportedImages: @zipFilePath ? @zipFilePath : false } }, status: :ok and return
        when 'png'
          collation_file = 'collation.css'
          config_xml     = %Q{<config><css xml:id="css">#{collation_file}</css></config>}
          job_response   = process_pipeline 'viscoll2svg', xml.to_xml, config_xml
          # outfile      = write_zip_file job_response, 'png'
          outfile      = "#{Rails.root}/public/xproc/#{@project.id}-png.zip"
          @zipFilePath = "#{@base_api_url}/transformations/zip/#{@project.id}-png"
          exportData   = []
          # open zip output stream (so we can write to the zip)
          Zip::OutputStream.open(outfile) do |zio|
            # Zip::OutputStream.write_buffer do |zio|
            Zip::File.open_buffer StringIO.new(job_response.body).read do |zip_input|
              zip_input.each do |input_entry|
                zio.put_next_entry input_entry.name
                zio.write input_entry.get_input_stream.read
                if File.extname(input_entry.name) == '.svg'
                  # use SecureRandom to prevent file name collisions;
                  #  e.g., MST1-1.svg => MST1-1.svg-d40498e50a.svg, MST1-1.svg-d40498e50a.svg.png
                  tmp_svg = File.join Dir.tmpdir, "#{File.basename(input_entry.name)}-#{SecureRandom.hex 5}.svg"
                  tmp_png = "#{tmp_svg}.png"

                  # write the svg to disk
                  File.open(tmp_svg, 'w+') { |f| f.puts input_entry.get_input_stream.read }
                  system "rsvg-convert -w 1024 #{tmp_svg} > #{tmp_png}"

                  # the png has the same name as the svg
                  png_name = input_entry.name.sub /\.svg$/, '.png'
                  zio.put_next_entry png_name
                  zio.write open(tmp_png, 'rb').read

                  # clean up
                  FileUtils.rm_f [tmp_svg, tmp_png]
                end
              end
            end
          end

          render json: { data: exportData, type: @format, Images: { exportedImages: @zipFilePath ? @zipFilePath : false } }, status: :ok and return
        when 'formula'
          job_response = process_pipeline 'viscoll2formulas', xml.to_xml

          outfile      = write_zip_file job_response, 'formula'
          @zipFilePath = "#{@base_api_url}/transformations/zip/#{@project.id}-formula"

          files = []
          Zip::File.open(outfile) do |zip_file|
            zip_file.each do |entry|
              if File.basename(entry.name).include? "formula"
                nokogiri_entry = zip_file.get_input_stream(entry) { |f| Nokogiri::XML(f) }
                content        = nokogiri_entry.xpath('//vc:formula/text()')
                type           = nokogiri_entry.xpath('//vc:formula/@type')
                format         = nokogiri_entry.xpath('//vc:formula/@format')
                formula        = "Type: #{type}\nFormat: #{format}\nFormula: #{content}\n\n"
                files << formula
              end
            end
          end
          exportData = files.sort

          render json: { data: exportData, type: @format, Images: { exportedImages: @zipFilePath ? @zipFilePath : false } }, status: :ok and return
        when 'html'
          collation_file = 'collation.css'
          config_xml     = %Q{<config><css xml:id="css">#{collation_file}</css></config>}
          image_list     = build_image_list @project
          job_response   = process_pipeline 'viscoll2html', xml.to_xml, config_xml, image_list
          outfile        = write_zip_file job_response, 'html'
          Zip::File.open(outfile) do |zip_file|
            zip_file.each do |file|
              if File.extname(file.name) == '.html'
                remove_xml_declaration(zip_file, file)
                add_doctype(zip_file, file)
                zip_file.rename(file.name, "HTML/#{file.name}")
              elsif File.extname(file.name) == '.xml'
                zip_file.rename(file.name, "XML/#{file.name}")
              elsif File.extname(file.name) == '.svg'
                zip_file.rename(file.name, "SVG/#{file.name}")
              end
            end
          end
          @zipFilePath = "#{@base_api_url}/transformations/zip/#{@project.id}-html"

          exportData = 'Please download your HTML below.'

          render json: { data: exportData, type: 'formula', Images: { exportedImages: @zipFilePath ? @zipFilePath : false } }, status: :ok and return
        else
          render json: { error: "Export format must be one of [json, xml, svg, formula, html]" }, status: :unprocessable_entity and return
        end
      else
        render json: { data: errors, type: @format }, status: :unprocessable_entity and return
      end
    rescue Exception => e
      render json: { error: e.message }, status: :internal_server_error and return
    end
  end

  private

  def set_project
    begin
      @project = Project.find(params[:id])
      if (@project.user_id != current_user.id)
        render json: { error: "" }, status: :unauthorized and return
      end
      @format = params[:format]
    rescue Exception => e
      render json: { error: "project not found with id " + params[:id] }, status: :not_found and return
    end
  end

  def remove_xml_declaration zip_file, input_file
    content     = zip_file.read(input_file.name)
    new_content = content.lines.to_a[1..-1].join
    zip_file.get_output_stream(input_file.name) { |f| f.puts new_content }
    zip_file.commit
  end

  def add_doctype zip_file, input_file
    content = zip_file.read(input_file.name)
    zip_file.get_output_stream(input_file.name) { |f| f.puts "<!-- Generated with VCEditor -->\n<!DOCTYPE html>\n" + content }
    zip_file.commit
  end

  def process_pipeline pipeline, xml_string, config_xml = nil, image_list = nil
    # run the pipeline
    xproc_uri = URI.parse "#{Rails.configuration.xproc['url']}/xproc/#{pipeline}/"
    xproc_req = Net::HTTP::Post.new(xproc_uri)
    form      = [['input', StringIO.new(xml_string)]]
    form << ['config', StringIO.new(config_xml)] if config_xml
    form << ['images', StringIO.new(image_list)] if image_list

    xproc_req.set_form(form, 'multipart/form-data')
    xproc_response = Net::HTTP.start(xproc_uri.hostname, xproc_uri.port) do |http|
      http.request(xproc_req)
    end
    response_hash  = JSON.parse(xproc_response.body)

    # TODO: Xproc#retreive_data; returns IO object
    job_url           = response_hash["_links"]["job"]["href"]
    job_uri           = URI.parse job_url
    job_req           = Net::HTTP::Get.new(job_uri)
    job_req["Accept"] = 'application/zip'
    job_response      = Net::HTTP.start(job_uri.hostname, job_uri.port) do |http|
      http.request(job_req)
    end
    job_response
  end

  def write_zip_file response, format
    outfile = "#{Rails.root}/public/xproc/#{@project.id}-#{format}.zip"
    File.open outfile, 'wb' do |f|
      f.puts response.body
    end
    outfile
  end
end
