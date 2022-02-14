`timescale 1ns/100ps
module FC(clk, rst, cmd, done, M_RW, M_A, M_D, F_IO, F_CLE, F_ALE, F_REN, F_WEN, F_RB);

  input clk;
  input rst;
  input [32:0] cmd;
  output reg done;
  output reg M_RW;
  output reg [6:0] M_A;
  inout  [7:0] M_D;
  inout  [7:0] F_IO;
  output reg F_CLE;
  output reg F_ALE;
  output reg F_REN;
  output reg F_WEN;
  input  F_RB;
parameter [3:0] IDLE = 4'b0000,
                CHECK = 4'b0001,
                S2 = 4'b0010,
                S3 = 4'b0011,
                S4 = 4'b0100,
                M1 = 4'b0101,
                M2 = 4'b0110,
                BUSY = 4'b0111,
                f_rstff = 4'b1000,
                f_read00 = 4'b1001,
                f_read01 = 4'b1010,
                f_write80 = 4'b1011,
                f_write10 = 4'b1100,
                f_erase60 = 4'b1101,
                WRITE = 4'b1110,
                f_idle = 4'b1111;




reg [3:0] curr,next;
reg [3:0] prev;
integer i;
reg [2:0] cnt_s2;
reg [9:0] cnt_d2f;
reg mc;
wire [7:0] fin;


wire [17:0] cmd_F_ADDR;
assign cmd_F_ADDR =  cmd[31:14];

reg [7:0] BLOCK_MEM [61:0];

assign fin = F_IO;

always@(posedge clk or posedge rst)begin
  if(rst)begin
    done <= 1'b0;
    curr <= IDLE;

    i <= 0;
    cnt_s2 <= 3'b0;
    cnt_d2f <= 10'd0;
    mc <= 1'b0;
  end
  else begin
    i = i+1;
    curr <= next;
    prev <= curr;
    if(curr == S2)begin
      if(cnt_s2 == 3'b011)
        cnt_s2 <= 3'b0;
      else
        cnt_s2 <= cnt_s2 + 3'b1;
    end
    else if(curr == S3)begin
      cnt_s2 <= 3'b0;
      cnt_d2f <= cnt_d2f + 10'd1;
    end
    else  if(curr == M1)begin
      cnt_s2 <= 3'b0;
      mc <= mc + 1'b1;
    end
    else
      cnt_s2 <= 3'b0;
  end
end

wire lock;
assign lock = (curr==IDLE)? 1'b0: 1'b1;



always@(negedge clk)begin
  if( i%512 ==1)
    done <= 1'b1;
  else begin
    done <= 1'b0;
  end
end


reg [7:0] data_from_mem;

reg [6:0] m; 


always@(posedge clk or posedge rst)begin
  if(rst)begin
    m <= 0;
  end
  else if (curr == M1)begin
    m <= m + 7'd1;
  end 
  else
    m <= m;
end

reg [17:0] A;
reg [7:0] to_f_com;



always@(*)begin
  case(curr)
    IDLE:begin
      next = M1;
    end
    BUSY:begin
      next = CHECK;
    end
    CHECK:begin
      next = S2;
    end
    S2:begin
      if(cnt_s2 == 3'b011 )begin
        next = S3;
      end
      else begin
        next = S2;
      end
    end
    S3:begin
      if(cnt_d2f <10'd62)
        next = S3;
      else
        next = f_write10; 
    end
    M1:begin
      if(m<7'd124| m == 6'd0)
        next = M1;
      else 
        next = BUSY;
    end
    BUSY:begin
      next = CHECK;
    end
    S4:begin
      next = S4;
    end
    f_write10:begin
      next = WRITE;
    end
    WRITE:begin
    end
    /*
    f_idle:begin
      next = f_idle;
    end
    f_rstff:begin
      next = f_rstff;
    end
    f_read00: next = f_write80;
    f_write80 :begin
                if(A[8])
                  next = f_read01;
                else
                  next = f_write10;
    end
    f_write10: next = (F_RB)?f_idle:f_write10;
    f_read01 : next = f_rstff;
    f_erase60 : next = f_rstff;
    */
    default:begin
      next = IDLE;
    end
  endcase
end

wire enable;
assign enable = cmd[32];
reg [7:0] fio_in;
reg [7:0] fio_reg;

reg [7:0] to_f_data;
assign F_IO = (enable)?8'bz:fio_reg;


//flash memory FSM
reg f_w_or_r;

//reg [2:0] f_curr,f_next;
/*
always@(posedge clk or posedge rst)begin
  if(rst)
    curr <= ;
  else
    f_curr <= f_next;
end
*/
/*
always@(*)begin
  case(curr)
    f_idle:begin
      next = f_idle;
    end
    f_rstff:begin
      next = f_rstff;
    end
    f_read00: next = f_write80;
    f_write80 :begin
                if(A[8])
                  next = f_read01;
                else
                  next = f_write10;
    end
    f_write10: next = (F_RB)?f_idle:f_write10;
    f_read01 : next = f_rstff;
    f_erase60 : next = f_rstff;
    default:next = f_idle;
  endcase
end
*/
/*
always@(*)begin
  case(curr)
    f_rstff:to_f_com = 8'hFF;
    f_read00:to_f_com = 8'h00 ;
    f_write80 :to_f_com = 8'h80;
    f_write10 :to_f_com = 8'h10;
    f_read01 :to_f_com = 8'h01;
    f_erase60 :to_f_com = 8'h60;
    default:to_f_com = 8'hFF;
  endcase
end
*/



integer k3;
integer k4;
always@(posedge clk)begin  
  if(rst)begin
    k3 <= 0;
    k4 <= 0;
  end
  else if(enable)
    fio_in <= F_IO;
  else begin
    case(curr)
      BUSY:begin
        fio_reg <= to_f_com;
      end
      CHECK:begin
        fio_reg <= to_f_com;
      end
      S2:begin
        case(cnt_s2)
          3'b000:
            fio_reg <= {A[7],A[6],A[5],A[4],A[3],A[2],A[1],A[0]};
          3'b001:
            fio_reg <= {A[16],A[15],A[14],A[13],A[12],A[11],A[10],A[9]};
          3'b010:
            fio_reg <= {7'b0,A[17]};
          3'b011:
            fio_reg <= A ;
          default:
            fio_reg <= fio_reg;
        endcase
      end
      S3:begin 
          fio_reg <= BLOCK_MEM[k3];
          k3 <= k3 + 1;
      end
      f_write10:begin
          //fio_reg <= to_f_com;
          fio_reg <= 8'hx;
      end
      WRITE:begin
        fio_reg <= 8'hx;
      end
    endcase
  end
end



reg [5:0] m_addr_cnt;
reg m_addrmode2;
wire [7:0] min;
assign min = M_D;
reg [7:0] mout;
assign M_D = (M_RW)? 8'bz: mout;

always@(posedge clk or posedge rst)begin
  if(rst)begin
    m_addr_cnt <= 6'd0;
    m_addrmode2 <= 1'b0;
  end
  else if(curr==M1 && prev != IDLE && ~m_addrmode2)begin
    m_addr_cnt <= m_addr_cnt + 6'd1;
    m_addrmode2 <= m_addrmode2 + 1'b1;
  end
  else
    m_addrmode2 <= m_addrmode2 + 1'b1;
end
reg [6:0] temp;
integer cnt_of_addr;
always@(negedge clk)begin
    case(cmd[32])
      1'b1:begin//vm vm vm vm vm vm vm 
      end
      1'b0:begin//Write
        case(curr)
          IDLE:begin
            //F_CLE <= 1'b0;
            //F_ALE <= 1'b1;
            //F_REN <= 1'b0;
            //F_WEN <= 1'b0;
          end
          CHECK:begin//指令
            F_CLE <= 1'b1;          
            //F_WEN = 1'b0;   
            F_ALE <= 1'b0;
            F_REN <= 1'b1;

            // M_RW =1'b1;
            to_f_com <= 8'h80;
          end
          S2:begin//位址
          A[8] = cmd[22];
            if(cnt_s2==3'b0)begin
              F_CLE <= 1'b0;
              //F_WEN = 1'b0;
              F_ALE <= 1'b1;
              F_REN <= 1'b1;

              M_RW <= 1'b1;

              A[0] <= cmd[14];
              A[1] <= cmd[15];
              A[2] <= cmd[16];
              A[3] <= cmd[17];
              A[4] <= cmd[18];
              A[5] <= cmd[19];
              A[6] <= cmd[20];
              A[7] <= cmd[21];

            end
            else if(cnt_s2 == 3'b001)begin
              F_CLE <= 1'b0;
              //F_WEN = 1'b0;
              F_ALE <= 1'b1;
              F_REN <= 1'b1;

              M_RW <= 1'b1;

              A[9] <= cmd[23];
              A[10] <= cmd[24];
              A[11] <= cmd[25];
              A[12] <= cmd[26];
              A[13] <= cmd[27];
              A[14] <= cmd[28];
              A[15] <= cmd[29];
              A[16] <= cmd[30];
            end
            else begin//輸入
              F_CLE <= 1'b0;
              //F_WEN = 1'b0;
              F_ALE <= 1'b1;
              F_REN <= 1'b1;

              M_RW <= 1'b1;

              A[17] <= cmd[31];
            end
          end
          S3:begin
            if(next == f_write10)begin
              F_CLE <= 1'b1;
            end
            else begin
              F_CLE <= 1'b0;
              //F_WEN = 1'b1;
              F_ALE <= 1'b0;
              F_REN <= 1'b1;

              M_RW <= 1'b1;
            end  
          end
          M1:begin
            F_ALE <= 1'b0;
            M_RW <= 1'b1;
            M_A <= cmd[13:7] + m_addr_cnt;
            F_CLE <= 1'b0;
          end 
          BUSY:begin
            F_CLE <= 1'b1;
            F_WEN <= 1'b0;
            F_ALE <= 1'b0;
            //F_IO = (enable)? 8'bz:fio_reg;
            F_REN <= 1'b1;

            to_f_com <= 8'hFF;
          
          end

          f_write10:begin
            if(prev == S3)begin
              F_CLE <= 1'b1;
              F_ALE <= 1'b0;
              //F_IO = (enable)? 8'bz:fio_reg;

              to_f_com <= 8'h10;
            end
            else begin
              F_CLE <= 1'b0;
            end
          end
          WRITE:begin
            F_CLE <= 1'b0;
            if(prev == WRITE)begin
              done <= 1'b1;
            end

          end
          /*
          f_rstff:to_f_com = 8'hFF;
          f_read00:to_f_com = 8'h00 ;
          f_write80:to_f_com = 8'h80;
          f_write10:to_f_com = 8'h10;
          f_read01:to_f_com = 8'h01;
          f_erase60:to_f_com = 8'h60;
          */
          default:begin
            F_ALE <= 1'b0;
            M_RW <= 1'b1;
            F_REN <= 1'b1;
            to_f_com <= 8'h80;
          end
        endcase
      end
    endcase
end


always@(*)begin
case(cmd[32])
      1'b1:begin//vm vm vm vm vm vm vm 
      end
      1'b0:begin//Write
        case(curr)
          CHECK:begin//指令
            to_f_com = 8'h80;
          end
          S2:begin//位址
          end
          S3:begin 
          end
          M1:begin
          end 
          BUSY:begin
            to_f_com = 8'hFF;
          end
          f_write10:begin
            to_f_com = 8'h10;
            fio_reg = to_f_com;
          end
          default:begin
            
          end
        endcase
      end
    endcase
end

always@(posedge clk or posedge rst)begin
  if(rst)
    F_WEN <= 1'b0;
  else if(curr == CHECK | curr == BUSY | curr == S2 | curr == S3 ) 
    F_WEN <= ~F_WEN;
  else if(curr == 4'h3 & next == 4'hc)
    F_WEN <= 1'b0;
end

/*
always@(*)begin
  F_WEN =  clk;
  if(curr == 4'hc | curr == 4'he)
    F_WEN = 1'b1;
end
*/

integer k;
reg blmode2;
always@(negedge clk or posedge rst)begin
  if(rst) begin
    k <= 0 ;
    blmode2 <= 1'b0;
  end
  else if(M_RW & ~blmode2)begin
      k <= k+1;
      blmode2 <= blmode2 + 1'b1;
      BLOCK_MEM[k] <= M_D;
  end
  else if(k==0)
    blmode2 <= 1'b0;
  else begin
      blmode2 <= blmode2 + 1'b1;
  end
end





endmodule
