# frozen_string_literal: true

json.set! 'Export' do
  json.project @data[:project]
  json.Groups @data[:groups]
  json.Leafs @data[:leafs]
  json.Rectos @data[:rectos]
  json.Versos @data[:versos]
  json.Terms @data[:terms]
end

json.set! 'Images' do
  json.exportedImages @zipFilePath || ''
end
