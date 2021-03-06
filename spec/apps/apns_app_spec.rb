module RailsPushNotifications
  describe APNSApp, type: :model do
    it 'creates an instance given valid attributes' do
      APNSApp.create! attributes_for :apns_app
    end

    describe 'validations' do

      let(:app) { build :apns_app }

      it 'requires an apns dev cert' do
        app.apns_dev_cert = nil
        expect(app).to_not be_valid
      end

      it 'requires an apns prod cert' do
        app.apns_prod_cert = nil
        expect(app).to_not be_valid
      end

      describe 'sandbox mode' do
        it 'automatically sets sandbox mode if missing' do
          app.sandbox_mode = nil
          expect do
            app.valid?
          end.to change { app.sandbox_mode }.from(nil).to true
        end

        it 'uses the value if given' do
          app.sandbox_mode = false
          expect do
            app.valid?
          end.to_not change { app.sandbox_mode }.from false
        end
      end
    end

    describe 'notifications relationship' do
      let(:app) { create :apns_app }

      it 'can create new notifications' do
        expect do
          app.notifications.create attributes_for :apns_notification
        end.to change { app.reload.notifications.count }.from(0).to 1
      end
    end

    describe '#push_notifications' do
      let(:app) { create :apns_app }
      let(:notifications) do
        (1..10).map { create :apns_notification, app: app }
      end
      let(:single_notification) { create :apns_notification, app: app }

      let(:connection) do
        instance_double(RubyPushNotifications::APNS::APNSConnection).
          as_null_object
      end

      before do
        allow(RubyPushNotifications::APNS::APNSConnection).
          to receive(:open).with(app.apns_dev_cert, app.sandbox_mode).
          and_return connection
        allow(IO).to receive(:select).and_return []
      end

      it 'assigns results' do
        expect do
          app.push_notifications
        end.to change {
          notifications.map do |n|
            n.reload.results && n.results.individual_results
          end
        }.from([nil] * 10).
          to([[RubyPushNotifications::APNS::NO_ERROR_STATUS_CODE]] * 10)
      end

      it 'marks as sent' do
        expect do
          app.push_notifications
        end.to change { single_notification.reload.sent }.from(false).to true
      end

      context 'with an already sent notification' do
        let!(:sent_notification) { create :apns_notification, app: app }

        before { app.push_notifications }

        it "doesn't send already sent notifications" do
          expect(connection).to_not receive(:write)
          app.push_notifications
        end
      end
    end
  end
end
