# frozen_string_literal: true

require "google_drive"
require "logger"

class Sync
  @@logger = Logger.new($stdout)

  def self.go
    session_src = GoogleDrive::Session.from_config("config-src.json")
    session_dest = GoogleDrive::Session.from_config("config-dest.json")

    session_src.collections.each do |folder_src|
      @@logger.info("Syncing folder: #{folder_src.title}")
      folder_dest = find_or_create_folder(folder_src, session_dest)
      folder_src.files.each do |file_src|
        @@logger.info("Syncing file: #{file_src.title}")
        find_or_create_file(file_src, folder_dest, session_dest)
      end
    end
  end

  def self.find_or_create_folder folder_src, session_dest
    folder = session_dest.collection_by_title(folder_src.title)
    if folder
      @@logger.info("Folder already exits: #{folder_src.title}")
      return folder
    end

    @@logger.info("Creating folder: #{folder_src.title}")
    session_dest.create_collection(folder_src.title, {created_time: folder_src.created_time,
                                                      modified_time: folder_src.modified_time,
                                                      description: folder_src.description})
  end

  def self.find_or_create_file file_src, folder_dest, session_dest
    if file_src.resource_type != "file"
      @@logger.info("Skipping non-file: #{file_src.title}")
      return nil
    end

    file = folder_dest.file_by_title(file_src.title)
    if file
      @@logger.info("File already exits: #{file_src.title}")
      return file
    end

    @@logger.info("Creating file: #{file_src.title}")
    io = StringIO.new
    file_src.download_to_io(io)
    file_metadata = {
      parents: [folder_dest.id],
      name: file_src.title,
      created_time: file_src.created_time,
      modified_time: file_src.modified_time,
      description: file_src.description,
      mime_type: file_src.mime_type,
      original_filename: file_src.original_filename}
    api_params = {
      upload_source: io,
      content_type: "application/octet-stream",
      fields: "*",
      supports_all_drives: true}
    session_dest.drive_service.create_file(file_metadata, api_params)
  end
end
