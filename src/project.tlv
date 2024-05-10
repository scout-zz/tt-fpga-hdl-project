\m5_TLV_version 1d: tl-x.org
\m5
   use(m5-1.0)
   
   
   // ########################################################
   // #                                                      #
   // #  Empty template for Tiny Tapeout Makerchip Projects  #
   // #                                                      #
   // ########################################################
   
   // ========
   // Settings
   // ========
   
   //-------------------------------------------------------
   // Build Target Configuration
   //
   var(my_design, tt_um_example)   /// The name of your top-level TT module, to match your info.yml.
   var(target, ASIC)   /// Note, the FPGA CI flow will set this to FPGA.
   //-------------------------------------------------------
   
   var(in_fpga, 1)   /// 1 to include the demo board. (Note: Logic will be under /fpga_pins/fpga.)
   var(debounce_inputs, 1)         /// 1: Provide synchronization and debouncing on all input signals.
                                   /// 0: Don't provide synchronization and debouncing.
                                   /// m5_if_defined_as(MAKERCHIP, 1, 0, 1): Debounce unless in Makerchip.
   
   // ======================
   // Computed From Settings
   // ======================
   
   // If debouncing, a user's module is within a wrapper, so it has a different name.
   var(user_module_name, m5_if(m5_debounce_inputs, my_design, m5_my_design))
   var(debounce_cnt, m5_if_defined_as(MAKERCHIP, 1, 8'h03, 8'hff))

\SV
   // Include Tiny Tapeout Lab.
   m4_include_lib(['https:/']['/raw.githubusercontent.com/os-fpga/Virtual-FPGA-Lab/35e36bd144fddd75495d4cbc01c4fc50ac5bde6f/tlv_lib/tiny_tapeout_lib.tlv'])

\TLV my_design()
   
   
   
   // ==================
   // |                |
   // | YOUR CODE HERE |
   // |                |
   // ==================
   
   // Note that pipesignals assigned here can be found under /fpga_pins/fpga.

   
   
   |sender
      @0
         $sender = ! *ui_in[7];
         $reset = *reset;

      ?$sender
         @0
            //*uo_out[7] = 1'b1;
 
            $in[6:0] = *ui_in[6:0];
       
            $an_input = $in[0] || $in[1] || $in[2] || $in[3];
            $counter[11:0] = $reset ? 12'b0 :
               $an_input ? >>1$counter + {10'b0,~>>1$counter[10]} :
                  12'b0; 
               
            //$do_send =  $counter[11] && !>>1$counter[11] ;
            $do_send =  $counter > >>1$counter; 
            //$send_out[7:0] = {5'b1000, $in[3:0], 1'b1};
            $send_out[4:1] = $in[3:0];
         @10
            $do_send_out = $do_send;
 
   |receiver
      @0
         $receiver = *ui_in[7];

      ?$receiver
         @0
            $dec = *ui_in[0];
            $data[3:0] = *ui_in[4:1];
            $reset = *reset;
            $rec_in_valid = ((>>1$dec == 0) && ($dec == 1));
            $invalid_input = ( {{3'b0},$data[3]} + {{3'b0},$data[2]} + {{3'b0},$data[1]} + {{3'b0},$data[0]}) > 4'b1;
            
            $recv_out[7:0] =
                $reset ? 8'b010_00000 :
                ! $rec_in_valid ? >>1$recv_out :
                $invalid_input ? 8'b0111_1001 :
                $data[0] ? 8'b0000_0110 :
                $data[1] ? 8'b0101_1011 :
                $data[2] ? 8'b0110_0110 :
                // Default
                           8'b0111_1111 ;
                 
   |output
      @0
         *uo_out[7:0] = /fpga|sender<>0$sender ? 
             {3'b100,/fpga|sender<>0$send_out[4:1],/fpga|sender>>10$do_send_out} : 
             /fpga|receiver<>0$recv_out;
   /*        
   |timing
      @0
         $reset = *reset;
         $timer[7:0] = 
            $reset ? 8'b0 :
            $timer[7:0] < 8'b1111_1111 ? >>1$timer[7:0] + 8'b1 : 8'b0 ;
   */         
            
 
            
            
         
    
   // Connect Tiny Tapeout outputs. Note that uio_ outputs are not available in the Tiny-Tapeout-3-based FPGA boards.
   m5_if_neq(m5_target, FPGA, ['*uio_out = 8'b0;'])
   m5_if_neq(m5_target, FPGA, ['*uio_oe = 8'b0;'])

// Set up the Tiny Tapeout lab environment.
\TLV tt_lab()
   // Connect Tiny Tapeout I/Os to Virtual FPGA Lab.
   m5+tt_connections()
   // Instantiate the Virtual FPGA Lab.
   m5+board(/top, /fpga, 7, $, , my_design)
   // Label the switch inputs [0..7] (1..8 on the physical switch panel) (top-to-bottom).
   m5+tt_input_labels_viz(['"UNUSED", "UNUSED", "UNUSED", "UNUSED", "UNUSED", "UNUSED", "UNUSED", "UNUSED"'])

\SV

// ================================================
// A simple Makerchip Verilog test bench driving random stimulus.
// Modify the module contents to your needs.
// ================================================

module top(input logic clk, input logic reset, input logic [31:0] cyc_cnt, output logic passed, output logic failed);
   // Tiny tapeout I/O signals.
   logic [7:0] ui_in, uo_out;
   m5_if_neq(m5_target, FPGA, ['logic [7:0] uio_in, uio_out, uio_oe;'])
   logic [31:0] r;  // a random value
   always @(posedge clk) r <= m5_if_defined_as(MAKERCHIP, 1, ['$urandom()'], ['0']);
   //assign ui_in = r[7:0];
   m5_if_neq(m5_target, FPGA, ['assign uio_in = 8'b0;'])
   logic ena = 1'b0;
   logic rst_n = ! reset;
   integer i;
   
   // Or, to provide specific inputs at specific times (as for lab C-TB) ...
   // BE SURE TO COMMENT THE ASSIGNMENT OF INPUTS ABOVE.
   // BE SURE TO DRIVE THESE ON THE B-PHASE OF THE CLOCK (ODD STEPS).
   // Driving on the rising clock edge creates a race with the clock that has unpredictable simulation behavior.
   initial begin
      #1  // Drive inputs on the B-phase.
         ui_in = 8'h0;
      #10 // Step 5 cycles, past reset.
         ui_in = 8'hFF;
      #2
      // Testing Sender ///////////////////////////////
      // Set Mode to Sender and clear inputs
         ui_in[7:0] = 8'b0000_0000;
      
      // Test Single Inputs
      for ( i = 0 ; i < 4; i++ ) begin
            ui_in[6:0] = 7'b000_0000;
            #40
         	ui_in[i] = 1'b1;
            //ui_in[0] = 1'b1;
            #40
         ;
      end
      
      // Test Double Inputs

      ui_in[6:0] = 7'b000_0000;
      #4
      ui_in[6:0] = 7'b100_0011;
      #4
      ui_in[6:0] = 7'b000_0000;
      #4
      ui_in[6:0] = 7'b100_0101;
      #4     
      ui_in[6:0] = 7'b000_0000;
      #4
      ui_in[6:0] = 7'b100_1010;
      #4
      ui_in[6:0] = 7'b000_0000;
      #4
      ui_in[6:0] = 7'b100_1001;
       
      // Testing Reciever ///////////////////////////////////////
      ui_in[7:0] = 8'b1000_0000;
      // Test Single Inputs
      for ( i = 0 ; i < 4; i++ ) begin
            ui_in[6:0] = 7'b000_0000;
            #40
         	ui_in[i + 1] = 1'b1;
            ui_in[0] = 1'b1;
            #40
         ;
      end
      
      // Test Double Inputs

      ui_in[4:0] = 5'b00000;
      #4
      ui_in[4:0] = 5'b00111;
      #4
      ui_in[4:0] = 5'b00000;
      #4
      ui_in[4:0] = 5'b01011;
      #4     
      ui_in[4:0] = 5'b00000;
      #4
      ui_in[4:0] = 5'b1010_1;
      #4
      ui_in[4:0] = 5'b0000_0;
      #4
      ui_in[4:0] = 5'b1001_1;
       
   end


   // Instantiate the Tiny Tapeout module.
   m5_user_module_name tt(.*);
   
   assign passed = top.cyc_cnt > 600;
   assign failed = 1'b0;
endmodule


// Provide a wrapper module to debounce input signals if requested.
m5_if(m5_debounce_inputs, ['m5_tt_top(m5_my_design)'])
\SV



// =======================
// The Tiny Tapeout module
// =======================

module m5_user_module_name (
    input  wire [7:0] ui_in,    // Dedicated inputs - connected to the input switches
    output wire [7:0] uo_out,   // Dedicated outputs - connected to the 7 segment display
    m5_if_eq(m5_target, FPGA, ['/']['*'])   // The FPGA is based on TinyTapeout 3 which has no bidirectional I/Os (vs. TT6 for the ASIC).
    input  wire [7:0] uio_in,   // IOs: Bidirectional Input path
    output wire [7:0] uio_out,  // IOs: Bidirectional Output path
    output wire [7:0] uio_oe,   // IOs: Bidirectional Enable path (active high: 0=input, 1=output)
    m5_if_eq(m5_target, FPGA, ['*']['/'])
    input  wire       ena,      // will go high when the design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);
   wire reset = ! rst_n;

\TLV
   /* verilator lint_off UNOPTFLAT */
   m5_if(m5_in_fpga, ['m5+tt_lab()'], ['m5+my_design()'])

\SV_plus
   
   // ==========================================
   // If you are using Verilog for your design,
   // your Verilog logic goes here.
   // Note, output assignments are in my_design.
   // ==========================================

\SV
endmodule
