-- This is a generic test compares row count in a generated model
-- with the row count in the other model (which might be a ref or a source)
-- and fails if they are not the same tests should return 0 rows to pass
-- and >=1 row to fail (you can configure this) You can also change the
-- severity of the test (say, to a warning only) in the test config of in
-- the yml file See: https://docs.getdbt.com/reference/resource-configs/severity

{% test count_equals_other(model, other)  %}

WITH model AS (
        SELECT COUNT(*) AS count_model FROM {{ model }}
    ),
    source AS (
        SELECT COUNT(*) AS count_other FROM {{ other }}
    )

SELECT * FROM model JOIN source WHERE count_model != count_other


{% endtest %}
