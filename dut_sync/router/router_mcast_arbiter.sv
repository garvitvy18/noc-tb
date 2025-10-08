//------------------------------------------------------------------------------
// lookahead_mcast_arbiter.sv  (aka router_mcast_arbiter)
// 3-input → 1-output wormhole arbiter with lock between HEAD..TAIL
// - Zero-cycle combinational grant when unlocked
// - Locks the winning input at HEAD; unlocks and rotates priority at TAIL
// - Works with your lookahead_router_multicast & lookahead_routing_multicast
//------------------------------------------------------------------------------

module router_mcast_arbiter (
    input  logic        clk,
    input  logic        rst,

    // One bit per input (3 inputs total)
    input  logic [2:0]  request,          // request[i] wants this output
    input  logic [2:0]  forwarding_head,  // head flit flowing from input i (1-hot/0)
    input  logic [2:0]  forwarding_tail,  // tail flit flowing from input i (1-hot/0)
    input  logic [2:0]  reset_arbiter,    // async channel reset (per-router-side)

    output logic [2:0]  grant,            // onehot0 grant
    output logic        grant_valid       // valid only when not locked and some request
);

    // -----------------------------
    // Lock between HEAD .. TAIL
    // -----------------------------
    logic       grant_locked;
    logic [2:0] saved_grant;        // latched grant while locked

    // HEAD qualifies a new lock (when unlocked) on the granted input
    wire forwarding_head_input = |(grant       & forwarding_head) & ~grant_locked;
    // TAIL qualifies unlock on the locked input
    wire forwarding_tail_input = |(saved_grant & forwarding_tail);

    always_ff @(posedge clk) begin
        if (rst | (|reset_arbiter)) begin
            grant_locked <= 1'b0;
            saved_grant  <= '0;
        end else begin
            if (forwarding_tail_input) begin
                grant_locked <= 1'b0;
                saved_grant  <= '0;
            end else if (forwarding_head_input) begin
                grant_locked <= 1'b1;
                saved_grant  <= grant;
            end
        end
    end

    // -----------------------------
    // Round-robin priority (3-way)
    // Priority updates when TAIL is forwarded (unlocked next cycle)
    // -----------------------------
    typedef logic [1:0] prio_t;   // 0..2
    prio_t prio_ptr, prio_ptr_n;

    // Helper: convert onehot0 to index; returns 0 if zero
    function automatic prio_t onehot_to_idx(input logic [2:0] oh);
        unique case (1'b1)
            oh[0]: onehot_to_idx = 2'd0;
            oh[1]: onehot_to_idx = 2'd1;
            oh[2]: onehot_to_idx = 2'd2;
            default: onehot_to_idx = 2'd0;
        endcase
    endfunction

    // On tail of locked packet: next starting priority = (locked_idx + 1) mod 3
    always_comb begin
        prio_ptr_n = prio_ptr;
        if (forwarding_tail_input) begin
            prio_ptr_n = (onehot_to_idx(saved_grant) == 2'd2) ? 2'd0
                                                              : onehot_to_idx(saved_grant) + 2'd1;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) prio_ptr <= 2'd0;        // input 0 wins after reset
        else      prio_ptr <= prio_ptr_n;
    end

    // -----------------------------
    // Combinational grant (unlocked)
    // Priority order: prio_ptr, prio_ptr+1, prio_ptr+2
    // -----------------------------
    function automatic logic [2:0] rr_grant(input logic [2:0] req, input prio_t base);
        logic [2:0] g;
        g = '0;
        unique case (base)
            2'd0: begin
                if (req[0]) g = 3'b001;
                else if (req[1]) g = 3'b010;
                else if (req[2]) g = 3'b100;
            end
            2'd1: begin
                if (req[1]) g = 3'b010;
                else if (req[2]) g = 3'b100;
                else if (req[0]) g = 3'b001;
            end
            default: begin // 2'd2
                if (req[2]) g = 3'b100;
                else if (req[0]) g = 3'b001;
                else if (req[1]) g = 3'b010;
            end
        endcase
        return g;
    endfunction

    logic [2:0] grant_unlocked;

    always_comb begin
        if (grant_locked) begin
            grant        = saved_grant;          // keep granting the same input while locked
            grant_valid  = 1'b0;                 // router only samples grant at reserve/head
        end else begin
            grant_unlocked = rr_grant(request, prio_ptr);
            grant        = grant_unlocked;
            grant_valid  = |request;             // zero-cycle response when unlocked
        end
    end

    // =========================================================================
    // Assertions (sim-only)
    // =========================================================================
`ifndef SYNTHESIS
    // pragma coverage off

    // Grant is onehot0
    a_grant_onehot0:
    assert property (@(posedge clk) disable iff (rst) $onehot0(grant))
      else $error("router_mcast_arbiter: grant not onehot0: %b", grant);

    // saved_grant is onehot0 while locked (or zero when not locked)
    a_saved_grant_onehot0:
    assert property (@(posedge clk) disable iff (rst)
        (grant_locked) |-> $onehot(saved_grant))
      else $error("router_mcast_arbiter: saved_grant must be onehot when locked: %b", saved_grant);

    // While locked, grant must equal saved_grant (stable lock)
    a_grant_equals_saved_when_locked:
    assert property (@(posedge clk) disable iff (rst)
        grant_locked |-> (grant == saved_grant))
      else $error("router_mcast_arbiter: grant changed while locked. grant=%b saved=%b", grant, saved_grant);

    // Lock only on a head flit that matches current grant
    a_lock_on_head_only:
    assert property (@(posedge clk) disable iff (rst)
        forwarding_head_input |-> (~grant_locked && $onehot(grant) && |(grant & forwarding_head)))
      else $error("router_mcast_arbiter: lock condition violated (head).");

    // Unlock only on tail flit of locked input
    a_unlock_on_tail_only:
    assert property (@(posedge clk) disable iff (rst)
        forwarding_tail_input |-> (grant_locked || $past(grant_locked)))
      else $error("router_mcast_arbiter: unlock without prior lock.");

    // Priority pointer updates only on tail of locked stream
    a_prio_updates_on_tail:
    assert property (@(posedge clk) disable iff (rst)
        forwarding_tail_input |-> (prio_ptr_n != $past(prio_ptr)))
      else $error("router_mcast_arbiter: priority did not update on tail.");

    // When unlocked and some request exists, grant_valid must be 1
    a_grant_valid_when_unlocked:
    assert property (@(posedge clk) disable iff (rst)
        (|request) && !grant_locked |-> grant_valid)
      else $error("router_mcast_arbiter: grant_valid should be 1 when requests present and unlocked.");

    // When locked, grant_valid should be 0 (router samples only at reserve/head)
    a_grant_valid_zero_when_locked:
    assert property (@(posedge clk) disable iff (rst)
        grant_locked |-> !grant_valid)
      else $error("router_mcast_arbiter: grant_valid should be 0 while locked.");

    // No X-propagation on control (helps catch upstream init bugs)
    a_no_x_request:
    assert property (@(posedge clk) disable iff (rst) !$isunknown(request))
      else $error("router_mcast_arbiter: request has X/Z.");

    a_no_x_fw_signals:
    assert property (@(posedge clk) disable iff (rst) !$isunknown(forwarding_head) && !$isunknown(forwarding_tail))
      else $error("router_mcast_arbiter: forwarding_head/tail has X/Z.");

    // pragma coverage on
`endif

endmodule

