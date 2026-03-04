library ieee;
use ieee.std_logic_1164.all;

entity hex_display_driver is
    port (
        data_in : in  std_logic_vector(31 downto 0); -- UART'tan gelen 32-bit veri
        -- DE2-115 HEX Pinleri
        hex0, hex1, hex2, hex3, hex4, hex5, hex6, hex7 : out std_logic_vector(6 downto 0)
    );
end entity;

architecture rtl of hex_display_driver is
signal internal_data : std_logic_vector(31 downto 0);

    -- 4-bitlik Hex değerini 7-segment desenine çeviren iç fonksiyon
    function to_7seg(hex_digit : std_logic_vector(3 downto 0)) return std_logic_vector is
    begin
        case hex_digit is
            when "0000" => return "1000000"; -- 0
            when "0001" => return "1111001"; -- 1
            when "0010" => return "0100100"; -- 2
            when "0011" => return "0110000"; -- 3
            when "0100" => return "0110011"; -- 4
            when "0101" => return "0110010"; -- 5
            when "0110" => return "0100010"; -- 6
            when "0111" => return "1111000"; -- 7
            when "1000" => return "0000000"; -- 8
            when "1001" => return "0010000"; -- 9
            when "1010" => return "0001000"; -- A
            when "1011" => return "0000011"; -- b
            when "1100" => return "1000110"; -- C
            when "1101" => return "0100001"; -- d
            when "1110" => return "0000110"; -- E
            when "1111" => return "0001110"; -- F
            when others => return "1111111"; -- Kapalı
        end case;
    end function;

begin
    -- 32-bit veriyi 4'er bitlik parçalara bölüp fonksiyonu çağırıyoruz
	 internal_data<=data_in;
    hex0 <= to_7seg(internal_data(3 downto 0));
    hex1 <= to_7seg(internal_data(7 downto 4));
    hex2 <= to_7seg(internal_data(11 downto 8));
    hex3 <= to_7seg(internal_data(15 downto 12));
    hex4 <= to_7seg(internal_data(19 downto 16));
    hex5 <= to_7seg(internal_data(23 downto 20));
    hex6 <= to_7seg(internal_data(27 downto 24));
    hex7 <= to_7seg(internal_data(31 downto 28));

end rtl;