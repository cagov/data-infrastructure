{# Computes the object name suffix from project and env.
   If project is set: "PROJECT_ENV" (e.g., SKILLS_MATCHING_DEV)
   If project is empty: "ENV" (e.g., DEV) #}

{% macro suffix() %}{{ project ~ '_' ~ env if project else env }}{% endmacro %}
