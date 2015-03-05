module Spree
  class ShipmentMailer < BaseMailer
    def shipped_email(carton, resend = false)
      @carton = carton.respond_to?(:id) ? carton : Spree::Carton.find(carton)
      subject = (resend ? "[#{Spree.t(:resend).upcase}] " : '')
      subject += "#{Spree::Config[:site_name]} #{Spree.t('shipment_mailer.shipped_email.subject')} ##{@carton.order.number}"
      mail(to: @carton.order.email, from: from_address, subject: subject)
    end
  end
end
