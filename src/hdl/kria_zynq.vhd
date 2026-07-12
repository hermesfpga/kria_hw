-- Top file

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity kria_zynq is
  port (
    UF1 : out STD_LOGIC;
    UF2 : out STD_LOGIC
  );
end kria_zynq;

architecture rtl of kria_zynq is

    signal user_led0 : std_logic_vector(0 downto 0);
    signal user_led1 : std_logic_vector(0 downto 0);

begin

  u_zynq_wrapper : entity work.zynq_wrapper
  port map(
    UF1         => user_led0,
    UF2         => user_led1,
    fan_en_b    => open
  );

UF1 <= user_led0(0);
UF2 <= user_led1(0);

end rtl;