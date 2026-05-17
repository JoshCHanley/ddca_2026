library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.sorting_network_pkg.all;

entity sorting_network is
    port (
        clk   : in std_ulogic;
        res_n : in std_ulogic;

        unsorted_ready : out std_ulogic;
        unsorted_data  : in  word_array_t(0 to 9);
        unsorted_valid : in  std_ulogic;

        sorted_ready   : in  std_ulogic;
        sorted_data    : out word_array_t(0 to 9);
        sorted_valid   : out std_ulogic
    );
end entity;

architecture pipelined of sorting_network is

    type stage_array_t is array(1 to 8) of word_array_t(0 to 9);

    type stages_t is record
        stages : stage_array_t;
        stage_valid : std_ulogic_vector(1 to 8);
    end record;

    signal s, s_nxt : stages_t;

    procedure compare_exchange(signal previous_word : in word_array_t; signal next_word : inout word_array_t;
     idx_1 : integer; idx_2 : integer) is
    begin
        if previous_word(idx_1) >= previous_word(idx_2) then
            next_word(idx_1) <= previous_word(idx_2);
            next_word(idx_2) <= previous_word(idx_1);
        end if;
    end procedure;

begin
    reset : process(res_n, clk)
    begin
        if res_n = '0' then
            s <= (
                stages => (others => (others => (others => '0'))),
                stage_valid => (others => '0')
            );
        elsif rising_edge(clk) then
            s <= s_nxt;
        end if;
    end process;

    comb : process(all) -- global stall
    begin
        s_nxt <= s;

        if sorted_ready = '1' then
            
            -- Stage 1
            s_nxt.stage_valid(1) <= unsorted_valid;
            s_nxt.stages(1) <= unsorted_data;
            if unsorted_valid = '1' then
                compare_exchange(unsorted_data, s_nxt.stages(1), 0, 8);
                compare_exchange(unsorted_data, s_nxt.stages(1), 1, 9);
                compare_exchange(unsorted_data, s_nxt.stages(1), 2, 7);
                compare_exchange(unsorted_data, s_nxt.stages(1), 3, 5);
                compare_exchange(unsorted_data, s_nxt.stages(1), 4, 6);
            end if;

            -- Stage 2
            s_nxt.stage_valid(2) <= s.stage_valid(1);
            s_nxt.stages(2) <= s.stages(1);
            if s.stage_valid(1) = '1' then
                compare_exchange(s.stages(1), s_nxt.stages(2), 0, 2);
                compare_exchange(s.stages(1), s_nxt.stages(2), 1, 4);
                compare_exchange(s.stages(1), s_nxt.stages(2), 5, 8);
                compare_exchange(s.stages(1), s_nxt.stages(2), 7, 9);
            end if;

            -- Stage 3
            s_nxt.stage_valid(3) <= s.stage_valid(2);
            s_nxt.stages(3) <= s.stages(2);
            if s.stage_valid(2) = '1' then
                compare_exchange(s.stages(2), s_nxt.stages(3), 0, 3);
                compare_exchange(s.stages(2), s_nxt.stages(3), 2, 4);
                compare_exchange(s.stages(2), s_nxt.stages(3), 5, 7);
                compare_exchange(s.stages(2), s_nxt.stages(3), 6, 9);
            end if;

            -- Stage 4
            s_nxt.stage_valid(4) <= s.stage_valid(3);
            s_nxt.stages(4) <= s.stages(3);
            if s.stage_valid(3) = '1' then
                compare_exchange(s.stages(3), s_nxt.stages(4), 0, 1);
                compare_exchange(s.stages(3), s_nxt.stages(4), 3, 6);
                compare_exchange(s.stages(3), s_nxt.stages(4), 8, 9);
            end if;

            -- Stage 5
            s_nxt.stage_valid(5) <= s.stage_valid(4);
            s_nxt.stages(5) <= s.stages(4);
            if s.stage_valid(4) = '1' then
                compare_exchange(s.stages(4), s_nxt.stages(5), 1, 5);
                compare_exchange(s.stages(4), s_nxt.stages(5), 2, 3);
                compare_exchange(s.stages(4), s_nxt.stages(5), 4, 8);
                compare_exchange(s.stages(4), s_nxt.stages(5), 6, 7);
            end if;

            -- Stage 6
            s_nxt.stage_valid(6) <= s.stage_valid(5);
            s_nxt.stages(6) <= s.stages(5);
            if s.stage_valid(5) = '1' then
                compare_exchange(s.stages(5), s_nxt.stages(6), 1, 2);
                compare_exchange(s.stages(5), s_nxt.stages(6), 3, 5);
                compare_exchange(s.stages(5), s_nxt.stages(6), 4, 6);
                compare_exchange(s.stages(5), s_nxt.stages(6), 7, 8);
            end if;

            -- Stage 7
            s_nxt.stage_valid(7) <= s.stage_valid(6);
            s_nxt.stages(7) <= s.stages(6);
            if s.stage_valid(6) = '1' then
                compare_exchange(s.stages(6), s_nxt.stages(7), 2, 3);
                compare_exchange(s.stages(6), s_nxt.stages(7), 4, 5);
                compare_exchange(s.stages(6), s_nxt.stages(7), 6, 7);
            end if;

            -- Stage 8
            s_nxt.stage_valid(8) <= s.stage_valid(7);
            s_nxt.stages(8) <= s.stages(7);
            if s.stage_valid(7) = '1' then
                compare_exchange(s.stages(7), s_nxt.stages(8), 3, 4);
                compare_exchange(s.stages(7), s_nxt.stages(8), 5, 6);
            end if;
        end if;

        sorted_valid <= s.stage_valid(8);
        if s.stage_valid(8) = '1' then
            sorted_data <= s.stages(8);
        else
            sorted_data <= (others => (others => '0'));
        end if;
    end process;

    unsorted_ready <= sorted_ready;


    -- comb : process(all) -- allows pushing together
    -- begin
    --     s_nxt <= s;

    --     --stage 1
    --     -- s_nxt.stage_valid(1) <= s.stage_valid(1);
    --     -- s_nxt.stages(1)      <= s.stages(1);
    --     if sorted_ready = '1' or s.stage_valid /= "11111111" then
    --         s_nxt.stage_valid(1) <= '0';
    --         if unsorted_valid = '1' then
    --             s_nxt.stages(1) <= unsorted_data;
    --             s_nxt.stage_valid(1) <= '1';
    --             compare_exchange(unsorted_data, s_nxt.stages(1), 0, 8);
    --             compare_exchange(unsorted_data, s_nxt.stages(1), 1, 9);
    --             compare_exchange(unsorted_data, s_nxt.stages(1), 2, 7);
    --             compare_exchange(unsorted_data, s_nxt.stages(1), 3, 5);
    --             compare_exchange(unsorted_data, s_nxt.stages(1), 4, 6);
    --         end if;
    --     end if;

    --     --stage 2
    --     -- s_nxt.stage_valid(2) <= s.stage_valid(2);
    --     -- s_nxt.stages(2)      <= s.stages(2);

    --     if sorted_ready = '1' or s.stage_valid(2 to 8) /= "1111111" then
    --         s_nxt.stage_valid(2) <= '0';
    --         if s.stage_valid(1) = '1' then
    --             s_nxt.stages(2) <= s.stages(1);
    --             s_nxt.stage_valid(2) <= '1';
    --             compare_exchange(s.stages(1), s_nxt.stages(2), 0, 2);
    --             compare_exchange(s.stages(1), s_nxt.stages(2), 1, 4);
    --             compare_exchange(s.stages(1), s_nxt.stages(2), 5, 8);
    --             compare_exchange(s.stages(1), s_nxt.stages(2), 7, 9);
    --         end if;
    --     end if;

    --     --stage 3
    --     -- s_nxt.stage_valid(3) <= s.stage_valid(3);
    --     -- s_nxt.stages(3)      <= s.stages(3);

    --     if sorted_ready = '1' or s.stage_valid(3 to 8) /= "111111" then
    --         s_nxt.stage_valid(3) <= '0';
    --         if s.stage_valid(2) = '1' then
    --             s_nxt.stages(3) <= s.stages(2);
    --             s_nxt.stage_valid(3) <= '1';
    --             compare_exchange(s.stages(2), s_nxt.stages(3), 0, 3);
    --             compare_exchange(s.stages(2), s_nxt.stages(3), 2, 4);
    --             compare_exchange(s.stages(2), s_nxt.stages(3), 5, 7);
    --             compare_exchange(s.stages(2), s_nxt.stages(3), 6, 9);
    --         end if;
    --     end if;

    --     --stage 4
    --     -- s_nxt.stage_valid(4) <= s.stage_valid(4);
    --     -- s_nxt.stages(4)      <= s.stages(4);

    --     if sorted_ready = '1' or s.stage_valid(4 to 8) /= "11111" then
    --         s_nxt.stage_valid(4) <= '0';
    --         if s.stage_valid(3) = '1' then
    --             s_nxt.stages(4) <= s.stages(3);
    --             s_nxt.stage_valid(4) <= '1';
    --             compare_exchange(s.stages(3), s_nxt.stages(4), 0, 1);
    --             compare_exchange(s.stages(3), s_nxt.stages(4), 3, 6);
    --             compare_exchange(s.stages(3), s_nxt.stages(4), 8, 9);
    --         end if;
    --     end if;
    --     --stage 5
    --     -- s_nxt.stage_valid(5) <= s.stage_valid(5);
    --     -- s_nxt.stages(5)      <= s.stages(5);

    --     if sorted_ready = '1' or s.stage_valid(5 to 8) /= "1111" then
    --         s_nxt.stage_valid(5) <= '0';
    --         if s.stage_valid(4) = '1' then
    --             s_nxt.stages(5) <= s.stages(4);
    --             s_nxt.stage_valid(5) <= '1';
    --             compare_exchange(s.stages(4), s_nxt.stages(5), 1, 5);
    --             compare_exchange(s.stages(4), s_nxt.stages(5), 2, 3);
    --             compare_exchange(s.stages(4), s_nxt.stages(5), 4, 8);
    --             compare_exchange(s.stages(4), s_nxt.stages(5), 6, 7);
    --         end if;
    --     end if;

    --     --stage 6
    --     -- s_nxt.stage_valid(6) <= s.stage_valid(6);
    --     -- s_nxt.stages(6)      <= s.stages(6);

    --     if sorted_ready = '1' or s.stage_valid(6 to 8) /= "111" then
    --         s_nxt.stage_valid(6) <= '0';
    --         if s.stage_valid(5) = '1' then
    --             s_nxt.stages(6) <= s.stages(5);
    --             s_nxt.stage_valid(6) <= '1';
    --             compare_exchange(s.stages(5), s_nxt.stages(6), 1, 2);
    --             compare_exchange(s.stages(5), s_nxt.stages(6), 3, 5);
    --             compare_exchange(s.stages(5), s_nxt.stages(6), 4, 6);
    --             compare_exchange(s.stages(5), s_nxt.stages(6), 7, 8);
    --         end if;
    --     end if;

    --     --stage 7
    --     -- s_nxt.stage_valid(7) <= s.stage_valid(7);
    --     -- s_nxt.stages(7)      <= s.stages(7);

    --     if sorted_ready = '1' or s.stage_valid(7 to 8) /= "11" then
    --         s_nxt.stage_valid(7) <= '0';
    --         if s.stage_valid(6) = '1' then
    --             s_nxt.stages(7) <= s.stages(6);
    --             s_nxt.stage_valid(7) <= '1';
    --             compare_exchange(s.stages(6), s_nxt.stages(7), 2, 3);
    --             compare_exchange(s.stages(6), s_nxt.stages(7), 4, 5);
    --             compare_exchange(s.stages(6), s_nxt.stages(7), 6, 7);
    --         end if;
    --     end if;

    --     --stage 8
    --     -- s_nxt.stage_valid(8) <= s.stage_valid(8);
    --     -- s_nxt.stages(8)      <= s.stages(8);

    --     if sorted_ready = '1' or s.stage_valid(8) = '0' then
    --         s_nxt.stage_valid(8) <= '0';
    --         if s.stage_valid(7) = '1' then
    --             s_nxt.stages(8) <= s.stages(7);
    --             s_nxt.stage_valid(8) <= '1';
    --             compare_exchange(s.stages(7), s_nxt.stages(8), 3, 4);
    --             compare_exchange(s.stages(7), s_nxt.stages(8), 5, 6);
    --         end if;
    --     end if;

    --     --output logic
    --     sorted_valid <= '0';
    --     sorted_data <= (others => (others => '0'));
    --     if s.stage_valid(8) = '1' then
    --         sorted_valid <= '1';
    --         sorted_data <= s.stages(8);
    --     end if;
    -- end process;


    -- unsorted_ready <= '1' when (sorted_ready = '1' or s.stage_valid /= "11111111") else '0';

end architecture;