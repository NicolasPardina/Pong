--
-- Fichero VHD que contiene una versión del juego Pong.
--
-- Está compuesto por un controlador de VGA para visualizarlo,
-- un teclado como componente, 2 máquinas de estados finitos que 
-- controlan el sentido de la pelota y la barra, una RAM en la que 
-- se guardan los colores del fondo (cambian con cada colisión barra-pelota),
-- un registro mod8 que lleva un recuento de esas colisiones, y la asignación 
-- del "bitmap" del display 7-segmentos según el valor de este registro.
--
--
-- Código de Nicolás Pardina Popp - Controlador VGA de Sara Román Navarro (procesos A B C D)
-- Práctica final de la asignatura Diseño Automático de Sistemas.
-- Universidad Complutense de Madrid.
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.std_logic_unsigned.all;


entity pong is
Port (
    clkFPGA : in std_logic;
    PS2CLK  : in std_logic;
    PS2DATA : in std_logic;
    reset   : in std_logic;
    vsyncb   : out std_logic;
    hsyncb   : buffer std_logic;
    rgb     : out std_logic_vector(11 downto 0);
    seg     : out std_logic_vector(6 downto 0)
);
end pong;


architecture Behavioral of pong is


component teclado is
Port (
    reset : in std_logic;
    PS2CLK : in std_logic;
    PS2DATA : in std_logic;
    movimiento_izquierda : out std_logic;
    movimiento_derecha : out std_logic
);
end component teclado;


component divisorFrecuencia is
Port (
    clkFPGA : in std_logic;
    reset : in std_logic;
    conmutarClk :  std_logic_vector(26 downto 0);
    clkOUT : out std_logic
    );
end component divisorFrecuencia;


-- Contadores que representan el pixel en el que encuentra el haz que los va modificando.
signal hcnt: std_logic_vector(8 downto 0);	
signal vcnt: std_logic_vector(9 downto 0);	

signal clock: std_logic;  --este es el pixel_clock para el ctrl de VGA.

-- Codificación de los distintos objetos que se representan en la pantalla.
signal objeto : std_logic_vector(2 downto 0);

signal negro : std_logic_vector(2 downto 0) := "000";
signal marcoSuperior : std_logic_vector(2 downto 0) := "001";
signal marcoInferior : std_logic_vector(2 downto 0) := "010";
signal marcoIzquierdo : std_logic_vector(2 downto 0) := "011";
signal marcoDerecho : std_logic_vector(2 downto 0) := "100";
signal rectanguloInterior : std_logic_vector(2 downto 0) := "101";
signal pelota : std_logic_vector(2 downto 0) := "110";
signal interior : std_logic_vector(2 downto 0) := "111";

-- Color del interior (el fondo) que cambia con cada rebote.
signal colorInterior : std_logic_vector(11 downto 0);

signal clk_pelota : std_logic;
signal clk_barra : std_logic;


-- Señales para la máquina de estados finitos de la pelota.
type DIRECCIONES is (NE,SE,SO,NO);
signal DIRECCION, SIG_DIRECCION:DIRECCIONES;

-- Señales para la máquina de estados finitos de la barra.
type DIRECCIONES_HORIZONTAL is (IZQUIERDA, ESTATICA,  DERECHA);
signal DIRECCION_HORIZONTAL, SIG_DIR_HOR:DIRECCIONES_HORIZONTAL;
signal laTeclaIzquierdaEstaPulsada : std_logic := '0';
signal laTeclaDerechaEstaPulsada : std_logic := '0';

-- Posición de la barra en la pantalla.
signal hbarra : std_logic_vector(8 downto 0) := "010001100";

-- Posición de la pelota en la pantalla.
signal hpelota: std_logic_vector(8 downto 0) := "010001100";	
signal vpelota: std_logic_vector(9 downto 0) := "0011001000";


signal contadorDeRebotes : std_logic_vector(2 downto 0) := "000";
signal colisionPelotaBarra : std_logic := '0';


-- Memoria en la que se guardan los colores del fondo de la pantalla.
type ram_type is array(7 downto 0) of std_logic_vector(11 downto 0);
signal RAM : ram_type := ("111100000000",
                           "000011111111",
                           "010010001111",
                           "110011001100",
                           "001100110011",
                           "111111110000",
                           "000011111111",
                           "111100001111");



begin


colorInterior <= RAM(to_integer(unsigned(contadorDeRebotes)));

rebotes : process
begin
    if(reset = '1') then
        contadorDeRebotes <= "000";
    elsif(clk_pelota'event and clk_pelota = '1') then
        if(colisionPelotaBarra = '1') then
            contadorDeRebotes <= contadorDeRebotes + 1;
        end if;  
    end if;  
end process rebotes;

seg <= "1000000" when contadorDeRebotes = "000" else
       "1111001" when contadorDeRebotes = "001" else
       "0100100" when contadorDeRebotes = "010" else 
       "0110000" when contadorDeRebotes = "011" else 
       "0011001" when contadorDeRebotes = "100" else  
       "0010010" when contadorDeRebotes = "101" else 
       "0000010" when contadorDeRebotes = "110" else 
       "1111000";                                    


teclado1 : teclado
port map(
    reset => reset,
    PS2CLK => PS2CLK,
    PS2DATA => PS2DATA,
    movimiento_izquierda => laTeclaIzquierdaEstaPulsada,
    movimiento_derecha => laTeclaDerechaEstaPulsada
);

divisor_barra : divisorFrecuencia
port map(
    clkFPGA => clkFPGA,
    reset => reset,
    conmutarClk => "000000000101110011000110000", -- Equivale a 190.000
    clkOUT => clk_barra
);

-- proceso que actualiza la posición de la barra
MOVIMIENTO_BARRA : process (clk_barra)
begin
    if(clk_barra' event and clk_barra = '1') then
        if (DIRECCION_HORIZONTAL = IZQUIERDA) then
            hbarra <= hbarra - 1;
        elsif (DIRECCION_HORIZONTAL = DERECHA) then
            hbarra <= hbarra + 1;             
        end if; 
     end if;
end process MOVIMIENTO_BARRA;


-- FSM BARRA

SINCRONO_BARRA : process (clk_barra, reset)
begin 
    if reset = '1' then
        DIRECCION_HORIZONTAL <= ESTATICA;
    elsif clk_barra'event and clk_barra ='1' then
        DIRECCION_HORIZONTAL <= SIG_DIR_HOR;
        
    end if;
end process SINCRONO_BARRA;

CAMBIO_DIR_BARRA : process(DIRECCION_HORIZONTAL, hbarra)
begin
    case DIRECCION_HORIZONTAL is
        when IZQUIERDA =>
            if (hbarra > 35 and laTeclaIzquierdaEstaPulsada = '1') then
                SIG_DIR_HOR <= IZQUIERDA;
            else
                SIG_DIR_HOR <= ESTATICA;
            end if;            
        when ESTATICA =>
            if(hbarra > 35 and laTeclaIzquierdaEstaPulsada = '1') then
                SIG_DIR_HOR <= IZQUIERDA;
            elsif(hbarra < 245 and laTeclaDerechaEstaPulsada = '1') then
                SIG_DIR_HOR <= DERECHA;
            else
               SIG_DIR_HOR <= ESTATICA;
            end if;   
        when DERECHA =>
            if(hbarra < 245 and laTeclaDerechaEstaPulsada = '1') then
               SIG_DIR_HOR <= DERECHA;
            else
               SIG_DIR_HOR <= ESTATICA;
            end if;
    end case;
end process CAMBIO_DIR_BARRA;




divisor_pelota : divisorFrecuencia
port map(
    clkFPGA => clkFPGA,
    reset => reset,
    conmutarClk => "000000000111101000010010000", -- Equivale a 250.000                    
    clkOUT => clk_pelota
);                          

-- proceso que actualiza la posición de la pelota
MOVIMIENTO_PELOTA : process (clk_pelota)
begin
    if(clk_pelota' event and clk_pelota = '1') then
        if (DIRECCION = NE) then
            hpelota <= hpelota + 1;
            vpelota <= vpelota - 2;
        elsif (DIRECCION = SE) then
            hpelota <= hpelota + 1;
            vpelota <= vpelota + 2;     
        elsif (DIRECCION = SO) then
            hpelota <= hpelota - 1;
            vpelota <= vpelota + 2;
        else
            hpelota <= hpelota - 1;
            vpelota <= vpelota - 2;                  
        end if; 
     end if;
end process MOVIMIENTO_PELOTA;

-- FSM PELOTA

SINCRONO_PELOTA : process (clk_pelota, reset)
begin 
    if reset = '1' then
        DIRECCION <= NE;
    elsif clk_pelota'event and clk_pelota ='1' then
        DIRECCION <= SIG_DIRECCION;
    end if;
end process SINCRONO_PELOTA;

CAMBIO_DIR_PELOTA : process(DIRECCION, hpelota, vpelota)
begin
    colisionPelotaBarra <=  '0';
    case DIRECCION is
        when NE =>
            if (hpelota > 265) then
                SIG_DIRECCION <= NO;
            elsif (vpelota < 30) then
                SIG_DIRECCION <= SE;
            else
                SIG_DIRECCION <= NE;
            end if;            
        when SE =>
            if(hpelota > 265) then
                SIG_DIRECCION <= SO;
            elsif (vpelota > 421) then
                SIG_DIRECCION <= NE;
            elsif ((vpelota + 10 > 388 or vpelota + 10 >  391) and (hpelota - 5 > hbarra - 25) and (hpelota + 5 < hbarra + 25)) then
                 SIG_DIRECCION <= NE;
                 colisionPelotaBarra <=  '1';
            else
               SIG_DIRECCION <= SE;
            end if;   
        when SO =>
            if(hpelota < 15) then
               SIG_DIRECCION <= SE;
            elsif (vpelota > 421) then
               SIG_DIRECCION <= NO;
            elsif ((vpelota + 10 > 388 or vpelota + 10 >  391) and (hpelota - 5 > hbarra - 25) and (hpelota + 5 < hbarra + 25)) then
               SIG_DIRECCION <= NO;
               colisionPelotaBarra <=  '1';
            else
               SIG_DIRECCION <= SO;
            end if;
 
        when NO =>
            if (hpelota < 15) then
               SIG_DIRECCION <= NE;
            elsif (vpelota < 30) then
               SIG_DIRECCION <= SO;
            else
               SIG_DIRECCION <= NO;
            end if;        
    end case;
end process CAMBIO_DIR_PELOTA;






      
-- CONTROLADOR VGA

divisor_pixel : divisorFrecuencia
port map(
    clkFPGA => clkFPGA,
    reset => reset,
    conmutarClk => "000000000000000000000000100", -- Equivale a 4
    clkOUT => clock
);

-- Este es el contador de clk pixel

A: process(clock,reset)
begin
	-- reset asynchronously clears pixel counter
	if reset='1' then
		hcnt <= "000000000";
	-- horiz. pixel counter increments on rising edge of dot clock
	elsif (clock'event and clock='1') then
		-- horiz. pixel counter rolls-over after 381 pixels
		if hcnt<380 then
			hcnt <= hcnt + 1;
		else
			hcnt <= "000000000";
		end if;
	end if;
end process;

-- Este es el contador de HSYNC

B: process(hsyncb,reset)
begin
	-- reset asynchronously clears line counter
	if reset='1' then
		vcnt <= "0000000000";
	-- vert. line counter increments after every horiz. line
	elsif (hsyncb'event and hsyncb='1') then
		-- vert. line counter rolls-over after 528 lines
		if vcnt<527 then
			vcnt <= vcnt + 1;
		else
			vcnt <= "0000000000";
		end if;
	end if;
end process;

-- Este es el comparador que comprueba si toca hacer sincronización horizontal

C: process(clock,reset)
begin
	-- reset asynchronously sets horizontal sync to inactive
	if reset='1' then
		hsyncb <= '1';
	-- horizontal sync is recomputed on the rising edge of every dot clock
	elsif (clock'event and clock='1') then
		-- horiz. sync is low in this interval to signal start of a new line
		if (hcnt>=291 and hcnt<337) then
			hsyncb <= '0';
		else
			hsyncb <= '1';
		end if;
	end if;
end process;

-- Este es el comparador que comprueba si toca hacer sincronización vertical

D: process(hsyncb,reset)
begin
	-- reset asynchronously sets vertical sync to inactive
	if reset='1' then
		vsyncb <= '1';
	-- vertical sync is recomputed at the end of every line of pixels
	elsif (hsyncb'event and hsyncb='1') then
		-- vert. sync is low in this interval to signal start of a new frame.
		if (vcnt>=490 and vcnt<492) then
			vsyncb <= '0';
		else
			vsyncb <= '1';
		end if;
	end if;
end process;



-- Este proceso 
process(hcnt, vcnt)
begin
    if ((hcnt > 0) and (hcnt < 280) and (vcnt > 0) and (vcnt < 20)) then
        objeto <= marcoSuperior;
    elsif ((hcnt > 0) and (hcnt < 280) and (vcnt > 430) and (vcnt < 450)) then
        objeto <= marcoInferior;
    elsif ((hcnt > 0) and (hcnt < 10) and (vcnt > 19) and (vcnt < 431)) then
        objeto <= marcoIzquierdo;
    elsif ((hcnt > 270) and (hcnt < 280) and (vcnt > 19) and (vcnt < 431)) then
        objeto <= marcoDerecho;
    elsif ((hcnt > hbarra - 25) and (hcnt < hbarra + 25) and (vcnt > 390) and (vcnt < 410)) then
        objeto <= rectanguloInterior;
    elsif ((hcnt > (hpelota - 5)) and (hcnt < (hpelota + 5)) and (vcnt < (vpelota + 10)) and (vcnt > (vpelota - 10))) then
        objeto <= pelota;
    elsif ((hcnt < 1) or (hcnt > 279) or (vcnt < 1) or (vcnt > 449)) then
        objeto <= negro;
    else
        objeto <= interior;
    end if;
end process;

process (objeto)
begin
    if(objeto = marcoSuperior) or (objeto = marcoInferior) or (objeto = marcoDerecho) or (objeto = marcoIzquierdo) then
        rgb <= "101010101010";
    elsif (objeto = rectanguloInterior) then
        rgb <= "010101010101";
    elsif (objeto = pelota) then
        rgb <= "000000001111";
    elsif (objeto = interior) then
        rgb <= colorInterior;
    else    
        rgb <= "000000000000";
    end if;
end process;


end Behavioral;
