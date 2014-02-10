object @variant
cache [__FILE__.gsub(/.*app\/views/, ""), root_object]
extends "spree/api/variants/variant"
child(:option_values => :option_values) { attributes *option_value_attributes }
child(:images => :images) { extends "spree/api/images/show" }