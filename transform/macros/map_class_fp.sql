{% macro map_class_fips(class_fips, k, v) -%}

{#
    Class Codes source: https://www.census.gov/library/reference/code-lists/class-codes.html
#}

{% set class_fips_dict = {
    "M2" : "A military or other defense installation entirely within a place",
    "C1" : "An active incorporated place that does not serve as a county subdivision equivalent",
    "U1" : "A census designated place with an official federally recognized name",
    "U2" : "A census designated place without an official federally recognized name"
} -%}

case
    {% for k, v in class_fips_dict.items() %}
    when "{{ class_fips }}" = '{{ k }}'
    then '{{ v }}'
    {% endfor %}
end

{%- endmacro %}
