$.fn.optionValueAutocomplete = function (options) {
  'use strict';

  // Default options
  options = options || {}
  var multiple = typeof(options['multiple']) !== 'undefined' ? options['multiple'] : true;
  var productSelect = options['productSelect'];

  this.select2({
    minimumInputLength: 3,
    multiple: multiple,
    initSelection: function (element, callback) {
      $.get(Spree.routes.option_value_search, {
        ids: element.val().split(',')
      }, function (data) {
        callback(multiple ? data : data[0]);
      });
    },
    ajax: {
      url: Spree.routes.option_value_search,
      datatype: 'json',
      params: { "headers": { "X-Spree-Token": Spree.api_key } },
      data: function (term, page) {
        var productId = typeof(productSelect) !== 'undefined' ? $(productSelect).select2('val') : null;
        return {
          q: {
            name_cont: term,
            variants_product_id_eq: productId
          },
          token: Spree.api_key
        };
      },
      results: function (data, page) {
        return { results: data };
      }
    },
    formatResult: function (option_value) {
      return option_value.name;
    },
    formatSelection: function (option_value) {
      return option_value.name;
    }
  });
};
