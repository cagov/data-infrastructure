{% macro map_class_fp(class_fp, k, v) -%}

{% set class_fp_dict = {
    "M2" : "A military or other defense installation entirely within a place",
    "C1" : "An active incorporated place that does not serve as a county subdivision equivalent",
    "U1" : "A census designated place with an official federally recognized name",
    "U2" : "A census designated place without an official federally recognized name"
} -%}

case
    {% for k, v in class_fp_dict.items() %}
    when "{{ class_fp }}" = '{{ k }}'
    then '{{ v }}'
    {% endfor %}
end

{%- endmacro %}
