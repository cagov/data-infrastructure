{% macro spatial_join_with_deduplication(left_model, right_model, left_cols, right_cols, left_geom="geometry", right_geom="geometry", op="st_intersects", kind="left", prefix="") %}

with {{ prefix }}_left_model_with_id as (
    select
        /* Generate a temporary ID for footprints. We will need this to group/partition
        by unique footprints further down. We could use a UUID, but integers are
        cheaper to generate and compare. */
        *, seq4() as _tmp_sjoin_id
    from {{ left_model }}
),

{{ prefix }}_joined as (
    select
      {% for lcol in left_cols %}
      {{ prefix }}_left_model_with_id.{{ lcol }},
      {% endfor %}
      {% for rcol in right_cols %}
      {{ right_model }}.{{ rcol }},
      {% endfor %}
      {{ prefix }}_left_model_with_id.{{ left_geom }},
      /* We don't actually need the intersection for every geometry, only for the
       ones that intersect more than one. However, in order to establish which
       ones intersect more than one, we need a windowed COUNT partitioned by
       _tmp_sjoin_id. This is an expensive operation, as it likely triggers a shuffle
       (even though it should already be sorted by _tmp_id). In testing we've found
       that it's cheaper to just do the intersection for all the geometries. */
      st_area(
        st_intersection({{ prefix }}_left_model_with_id.{{ left_geom }}, {{ right_model }}.{{ right_geom }})
      ) as _tmp_sjoin_intersection,
      {{ prefix }}_left_model_with_id._tmp_sjoin_id
    from {{ prefix }}_left_model_with_id
    {{ kind }} join {{ right_model }}
    on {{ op }}({{ prefix }}_left_model_with_id.{{ left_geom }}, {{ right_model }}.{{ right_geom }})
),

{{ prefix }}_deduplicated as (
    select
      -- Snowflake doesn't support geometries in max_by. It should, but it doesn't.
      -- Fortunately, we know that the geometries are identical when partitioned
      -- by _tmp_sjoin_id, so we can just choose any_value.
      any_value({{ left_geom }}) as {{ left_geom }},
      {% for lcol in left_cols %}
      max_by({{ lcol }}, _tmp_sjoin_intersection) as {{ lcol }},
      {% endfor %}
      {% for rcol in right_cols %}
      max_by({{ rcol }}, _tmp_sjoin_intersection) as {{ rcol }}{{ "," if not loop.last }}
      {% endfor %}
    from {{ prefix }}_joined
    group by _tmp_sjoin_id
)

select * from {{ prefix }}_deduplicated
{%- endmacro -%}
