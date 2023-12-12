# frozen_string_literal: true

FactoryGirl.define do
  sequence :image_filename do |n|
    "Image #{n}"
  end

  sequence :image_fileid, &:to_s

  sequence :image_original_filename do |n|
    "image_#{n}"
  end

  factory :image do
    filename { generate(:image_filename) }

    factory :pixel do
      filename { 'pixel.png' }
      fileID { 'pixel' }
      metadata do
        {
          "filename": 'pixel.png',
          "size": 20_470,
          "mime_type": 'image/png'
        }
      end
    end

    factory :shiba_inu do
      filename { 'shiba_inu.png' }
      fileID { 'shiba_inu' }
      metadata do
        {
          "filename": 'shiba_inu.png',
          "size": 20_470,
          "mime_type": 'image/png'
        }
      end
    end

    factory :viscoll_logo do
      filename { 'viscoll_logo.png' }
      fileID { 'viscoll_logo' }
      metadata do
        {
          "filename": 'viscoll_logo.png',
          "size": 20_470,
          "mime_type": 'image/png'
        }
      end
    end
  end
end
