$(document).ready(function() {
  var formFields = $("[data-hook='admin_customer_return_form_fields'], \
                     [data-hook='admin_return_authorization_form_fields']");

  if(formFields.length > 0) {
    $('.reimbursement-type-bulk-updater').on('click', function(ev) {
      ev.preventDefault();
      var selectedType = $(ev.currentTarget).parent().find('select').select2('val');
      var reimbursementTypeSelectBoxes = $(ev.currentTarget).parents('fieldset:first').find('.return-items-table select');

      $.each(reimbursementTypeSelectBoxes, function(i, selectBox) {
        selectBox = $(selectBox);
        if(selectBox.parents('tr').find('input.add-item:checked').length > 0) {
          selectBox.select2('val', selectedType);
        }
      });
    });
  }
});
