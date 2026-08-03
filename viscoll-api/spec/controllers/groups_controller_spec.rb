require 'rails_helper'

RSpec.describe GroupsController, type: :controller do
  describe '#find_group_project' do
    it 'raises VCError with the structured 422 when the project is missing' do
      missing_id = 'nonexistent-project-id'

      expect {
        controller.send(:find_group_project, missing_id)
      }.to raise_error(ApplicationController::VCError) do |error|
        expect(error.status).to eq(:unprocessable_entity)
        expect(error.json).to eq(
          group: { project_id: ["project not found with id #{missing_id}"] }
        )
      end
    end
  end
end
