jQuery ->
  $('.stock_item_backorderable').on 'click', ->
    $(@).parent('form').submit()
  $('.toggle_stock_item_backorderable').on 'submit', ->
    Spree.ajax
      type: @method
      url: @action
      data: $(@).serialize()
    false

$(document).ready ->
  return unless $('#listing_product_stock').length > 0
    
  $("#listing_product_stock .fa-edit").on 'click', (ev) ->
    ev.preventDefault()
    stockItemId = $(ev.currentTarget).data('id')
    hideReadOnlyElements(stockItemId)
    resetCountOnHandInput(stockItemId)
    showEditForm(stockItemId)

  $("#listing_product_stock .fa-void").on 'click', (ev) ->
    ev.preventDefault()
    stockItemId = $(ev.currentTarget).data('id')
    hideEditForm(stockItemId)
    showReadOnlyElements(stockItemId)

  $("#listing_product_stock .fa-check").on 'click', (ev) ->
    ev.preventDefault()
    stockItemId = $(ev.currentTarget).data('id')
    stockLocationId = $(ev.currentTarget).data('location_id')
    countOnHandDiff = calculateCountOnHandDiff(stockItemId)
    Spree.ajax
      url: "#{Spree.routes.stock_items_api(stockLocationId)}/#{stockItemId}"
      type: "PUT"
      data:
        stock_item:
          count_on_hand: countOnHandDiff
      success: (stockItem) =>
        updateSuccessHandler(stockItem)
        show_flash("success", "Updated successfully")
      error: (errorData) ->
        show_flash("error", errorData.responseText)

  showReadOnlyElements = (stockItemId) ->
    toggleReadOnlyElements(stockItemId, true)

  hideReadOnlyElements = (stockItemId) ->
    toggleReadOnlyElements(stockItemId, false)

  toggleReadOnlyElements = (stockItemId, show) ->
    textCssDisplay = if show then 'block' else 'none'
    toggleButtonVisibility('edit', stockItemId, show)
    $("#count-on-hand-#{stockItemId} span").css('display', textCssDisplay)

  showEditForm = (stockItemId) ->
    toggleEditFormVisibility(stockItemId, true)

  hideEditForm = (stockItemId) ->
    toggleEditFormVisibility(stockItemId, false)

  toggleEditFormVisibility = (stockItemId, show) ->
    inputCssDisplay = if show then 'block' else 'none'
    toggleButtonVisibility('void', stockItemId, show)
    toggleButtonVisibility('check', stockItemId, show)
    $("#count-on-hand-#{stockItemId} input[type='number']").css('display', inputCssDisplay)

  toggleButtonVisibility = (buttonIcon, stockItemId, show) ->
    cssDisplay = if show then 'inline-block' else 'none'
    $(".fa-#{buttonIcon}[data-id='#{stockItemId}']").css('display', cssDisplay)

  resetCountOnHandInput = (stockItemId) ->
    tableCell = $("#count-on-hand-#{stockItemId}")
    countText = tableCell.find('span').text().trim()
    tableCell.find("input[type='number']").val(countText)

  calculateCountOnHandDiff = (stockItemId) ->
    currentValue = parseInt($("#count-on-hand-#{stockItemId} span").text(), 10)
    updatedValue = parseInt($("#count-on-hand-#{stockItemId} input[type='number']").val(), 10)
    updatedValue - currentValue
  
  updateSuccessHandler = (stockItem) ->
    $("#count-on-hand-#{stockItem.id} span").text(stockItem.count_on_hand)
    hideEditForm(stockItem.id)
    showReadOnlyElements(stockItem.id)