//= require_self
$(document).ready(function() {
  if ($('#customer_autocomplete_template').length > 0) {
    window.customerTemplate = Handlebars.compile($('#customer_autocomplete_template').text());
  }

  formatCustomerResult = function(customer) {
    return customerTemplate({
      customer: customer,
      bill_address: customer.bill_address,
      ship_address: customer.ship_address
    })
  }

  if ($("#customer_search").length > 0) {
    $("#customer_search").select2({
      placeholder: Spree.translations.choose_a_customer,
      ajax: {
        url: Spree.routes.user_search,
        datatype: 'json',
        data: function(term, page) {
          return { q: term }
        },
        results: function(data, page) {
          return { results: data }
        }
      },
      dropdownCssClass: 'customer_search',
      formatResult: formatCustomerResult,
      formatSelection: function (customer) {
        $('#order_email').val(customer.email);
        $('#order_user_id').val(customer.id);

        return customer.email;
      }
    })
  }

  var order_use_billing_input = $('input#order_use_billing');

  var order_use_billing = function () {
    if (!order_use_billing_input.is(':checked')) {
      $('#shipping').show();
    } else {
      $('#shipping').hide();
    }
  };

  order_use_billing_input.click(function() {
    order_use_billing();
  });

  order_use_billing();
});
