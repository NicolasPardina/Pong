--
-- Fichero VHD que contiene un divisor de frecuencia.
--
-- Est� compuesto por un registro en el que se guarda un contador desde 0 hasta 
-- el valor recibido en la se�al de entrada conmutarClk, cuando se alcanza este valor 
-- se alterna el valor de la se�al de salida y se reinicia el contador. Que tambi�n 
-- ocurre al recibir "HIGH" en la se�al de reset (as�ncrono).
-- 
-- C�digo de Nicol�s Pardina Popp.
-- Pr�ctica final de la asignatura Dise�o Autom�tico de Sistemas.
-- Universidad Complutense de Madrid.
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_unsigned.all;

entity divisorFrecuencia is
Port (
    clkFPGA : in std_logic;
    reset : in std_logic;
    conmutarClk :  std_logic_vector(26 downto 0);
    clkOUT : out std_logic
    );
end divisorFrecuencia;

architecture Behavioral of divisorFrecuencia is

signal cuenta : std_logic_vector(26 downto 0);
signal salida : std_logic := '0';

begin

clkOUT <= salida;

process (clkFPGA, reset)
begin
    if(reset = '1') then
        cuenta <= (others => '0');
     elsif (clkFPGA'event and clkFPGA = '1') then
        if (cuenta = conmutarClk) then
            cuenta <= (others => '0');
            salida <= not salida;
        else
           cuenta <= cuenta + 1;
        end if;
      end if;
end process;

end Behavioral;
