--
-- Fichero VHD que contiene la interfaz del teclado.
--
-- Est� compuesto por un registro de desplazamiento con reset as�ncrono que se
-- recibe como entrada, as� como las se�ales PS2CLK y PS2DATA que genera el teclado PS/2.
-- Cuando se detecta que se est� pulsando la tecla de direcci�n derecha o izquierda,
-- se cambia a "HIGH" la se�al de salida correspondiente.
-- 
-- C�digo de Nicol�s Pardina Popp.
-- Pr�ctica final de la asignatura Dise�o Autom�tico de Sistemas.
-- Universidad Complutense de Madrid.
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity teclado is
Port (
    reset : in std_logic;
    PS2CLK : in std_logic;
    PS2DATA : in std_logic;
    movimiento_izquierda : out std_logic;
    movimiento_derecha : out std_logic
);
end teclado;

architecture Behavioral of teclado is

-- Registro de desplazamiento
signal scancode : std_logic_vector(0 to 21) := (others => '0');


begin

movimiento_izquierda <= '1' when scancode(2 to 9) = "01101011" and scancode(13 to 20) /= "11110000" else
                        '0';                        
                        
movimiento_derecha <= '1' when scancode(2 to 9) = "01110100" and scancode(13 to 20) /= "11110000" else
                      '0';

process (PS2CLK, scancode)
begin
    if(reset = '1') then
        scancode <= (others => '0');
    elsif(PS2CLK'event and PS2CLK = '0') then
        scancode <= PS2DATA & scancode(0 to 20) ;
    end if;
end process;

end Behavioral;
