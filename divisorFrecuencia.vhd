--
-- Fichero VHD que contiene un divisor de frecuencia.
--
-- Está compuesto por un registro en el que se guarda un contador desde 0 hasta 
-- el valor recibido en la señal de entrada conmutarClk, cuando se alcanza este valor 
-- se alterna el valor de la señal de salida y se reinicia el contador. Que también 
-- ocurre al recibir "HIGH" en la señal de reset (asíncrono).
-- 
-- Código de Nicolás Pardina Popp.
-- Práctica final de la asignatura Diseño Automático de Sistemas.
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
