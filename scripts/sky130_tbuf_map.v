module $_TBUF_ (
    input  A,
    input  E,
    output Y
);

    wire enable_b;

    $_NOT_ _TECHMAP_INV_ (
        .A(E),
        .Y(enable_b)
    );

    sky130_fd_sc_hdll__ebufn_1 _TECHMAP_REPLACE_ (
        .A(A),
        .TE_B(enable_b),
        .Z(Y)
    );

endmodule
