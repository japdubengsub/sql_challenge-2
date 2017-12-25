DECLARE @in table
(
    in_rn                    int,
    in_operday               date,
    in_operation_sum         money
)
INSERT @in (in_rn, in_operday, in_operation_sum)
VALUES
(1, '2015-01-01', 100),
(2, '2015-01-04', 200),
(3, '2015-01-08', 300),
(4, '2015-01-16', 400)




DECLARE @out table
(
    out_rn                  int,
    out_operday             date,
    out_operation_sum       money
)
INSERT @out (out_rn, out_operday, out_operation_sum)
VALUES
(1, '2015-01-05', 70 ),
(2, '2015-01-10', 10 ),
(3, '2015-01-12', 100),
(4, '2015-01-19', 440)




;WITH cte_in AS
(
    SELECT
        r.*,
        --  running total without amount of current operation
        in_amount_before = ISNULL(SUM(r.in_operation_sum) OVER(ORDER BY r.in_operday ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING), 0),
        --  running total with amount of current operation
        in_amount_after  = SUM(r.in_operation_sum) OVER(ORDER BY r.in_operday ROWS UNBOUNDED PRECEDING)
    FROM @in            r
),
cte_out AS
(
    SELECT
        w.*,
        out_amount_before = ISNULL(SUM(w.out_operation_sum) OVER(ORDER BY w.out_operday ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING), 0),
        out_amount_after  = SUM(w.out_operation_sum) OVER(ORDER BY w.out_operday ROWS UNBOUNDED PRECEDING)
    FROM @out           w
),
cte_pre_calc AS
(
    SELECT
        r.*,
        w.*,
        --  The maximum possible amount of withdrawal from the deposit
        out_sum_max     = r.in_amount_after - w.out_amount_before,
        --  the amount of previous withdrawals in the context of a single withdrawal if it is divided into several
        prev_out_sum    = LAG(r.in_amount_after - w.out_amount_before, 1, 0) OVER(PARTITION BY w.out_operday ORDER BY w.out_operday)
    FROM cte_in                             r
        INNER JOIN cte_out                  w
            ON r.in_operday <= w.out_operday            --  here consider that on the same date deposit occurs before withdrawals, otherwise use strong <
            AND r.in_amount_before < w.out_amount_after
            AND r.in_amount_after > w.out_amount_before
)
--/*
SELECT
    --cte.*,
    cte.in_operday,
    cte.out_operday,
    out_sum =   CASE
                    WHEN cte.out_sum_max >= cte.out_operation_sum
                        THEN cte.out_operation_sum - cte.prev_out_sum
                    ELSE cte.out_sum_max - cte.prev_out_sum
                END
FROM cte_pre_calc       cte
ORDER BY cte.out_rn, cte.in_rn
