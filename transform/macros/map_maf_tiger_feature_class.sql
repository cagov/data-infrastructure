{% macro map_maf_tiger_feature_class(maf_tiger_feature_class, k, v) -%}

{% set maf_tiger_feature_class_dict = {
    "G4110" : "Incorporated Place",
    "G4210" : "Census Designated Place",
    "G5040" : "Tabulation Block"
} -%}

case
    {% for k, v in maf_tiger_feature_class_dict.items() %}
    when "{{ maf_tiger_feature_class }}" = '{{ k }}'
    then '{{ v }}'
    {% endfor %}
end

{%- endmacro %}
