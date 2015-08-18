#!/bin/bash -i

##################################################################################
#                                                                                #
#    Copyright (C) 2012 Doriedson Alves Galdino de Oliveira                      #
#                       Thiago Andre Silva                                       #
#                       Vitor Augusto Andrioli                                   #
#                                                                                #
#    This program is free software: you can redistribute it and/or modify        #
#    it under the terms of the GNU General Public License as published by        #
#    the Free Software Foundation, either version 3 of the License, or           #
#    (at your option) any later version.                                         #
#                                                                                #
#    This program is distributed in the hope that it will be useful,             #
#    but WITHOUT ANY WARRANTY; without even the implied warranty of              #
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the               #
#    GNU General Public License for more details.                                #
#                                                                                #
#    You should have received a copy of the GNU General Public License           #
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.       #
#                                                                                #
##################################################################################

# Autores:
# Doriedson RA 1430431213050
# Thiago Andre RA 1430431213077
# Vitor Augusto RA 1430431213047
# Data: 24/04/2012

# DESCRICAO:
# Jogo do Mario Bros estilo nintendo 8 bits.

# CHANGELOG:

# 2012/05/09 (Doriedson, Vitor, Thiago)
# Eliminada a funcao LoadGame que carregava o mapa da primeira fase em caracters e criada a LoadFase1 para gerar a primeira fase 
# a partir de mapa de caracters menores. 
# Criada funcao MontaCanvas para pegar o tamanho da tela em um mapa de caracters e jogar no buffer

# 2012/05/15 (Doriedson, Vitor, Thiago)
# Adicionada Funcao Splash para mostrar as vidas do personagem e definir abertura de tela
# Adicionada Funcao ColisaoBuraco para relizar colisão com os buracos do cenario
# Adicionada Funcao Dead para relizar animação da morte do personagem
# Adicionada Funcao Play para centralizar as rotinas de execução de audio

# 2012/05/22 (Doriedson, Vitor, Thiago)
# Adicionada Funcao ColisaoBloco
# Adicionada Funcao ColisaoCoin

# 2012/05/29 (Doriedson, Vitor, Thiago)
# Adicionado Inimigo na fase
# Adicionada Funcao ResizeScreen para ajustar o jogo no terminal caso o terminal seja redimensionado
# Alteradas algumas variaveis, inclusive a do jogador, para vetor, para melhorar o calculo de colisao e possivel adicao de cor nos itens da tela como o personagem e as moedas.

# 2012/06/05 (Doriedson, Vitor, Thiago)
# Corrigido bug na funcao LoadFase1 (toda vez que o personagem morre a funcao eh chamada e os vetores fasel[37] [38] e [39] eram incrementados,
# nunca sendo zerados)
# Removido tput clear na funcao resizeScreen para evitar scrolling no terminal e adicionado string com espaços
# Adicionada tela de gameover
# Adicionada funcao para incrementar score e salvar topscore
# Criada funcao MontaMenu, quando mudava o tamanho do terminal não redesenhava e estourava o grafico
# Alterada funcao FPS para controle de uma unica unidade do tempo
# Ajustado movimento do personagem para ficar com mais suavidade
# Retirado desenho das moedas no buffer da fase e criada funcao DrawCoin para desenhar no buffer da tela e realizar animacao
# Criada variavel _edgeScreen para permitir renderizar desenhos que ficam com parte visivel na camera e parte nao visivel
# Corrigido problema de colisao com o inimigo que era avaliado soh o primeiro pois saia da funcao com return e nao avaliava os outros
# Usado -i na frente do /bash/bin inicialamente para importar variaveis como LINES e COLUMNS para nao realizar processos com tput ...
# ...mas foi verificado que é mais lento  do que o comando tput entao permanene pelo motivo de suprir a mensagem de retorno de erro ...
# ...quando a musica de background é morta pelo kill.

# [ FUNCOES ] --------------------------------------------------------------------------------------------------------

_version="1.0" #20120618

# Funcao para pegar tamanho do terminal
function TerminalSize {

	# Cria variavel com altura do terminal em linhas
	local _tmph=`tput lines`

	# Cria variavel com largura do terminal em colunas
	local _tmpw=`tput cols`

	# Verifica se houve mudança no tamando do terminal
	if [ $_tmph -ne $_height ] || [ $_tmpw -ne $_width ]; then

		_height=$_tmph
		_width=$_tmpw

		ResizeScreen

	fi

}

# Funcao para redimensionamento do terminal
function ResizeScreen {

	# Inicializa variavel para definir o meio da tela em largura para economizar recalculo no jogo
	_widthMid=$((_width / 2))

	# Cria variavel para determinar onde começara o desenho da tela subtraindo a altura de desenho do jogo (36 linhas)
	_initY=$((_height - _heightScreen))

	#Cria variaveis para verificar se o terminal eh maior que 80 colunas e centraliza a tela do menu no meio com espaços em volta
	_spaceIni=""
	_spaceFim=""

	if [ $_width -gt 80 ]; then

		_i=$(( (( _width - 80 )) / 2 ))
		_f=$(( (( _width - 80 )) - _i ))
		_spaceIni=`printf "%${_i}s"`
		_spaceFim=`printf "%${_f}s"`
	fi
	
	((_s= _width*_height))

	_clearScreen=`printf "%${_s}s"`

	# Cria uma variavel com espaços da largura da tela
	_spaceScreen=`printf "%${_width}s"`

	# limpa o topo da tela onde não será usado na screen do jogo
#	_screen=""
#	for (( _k=0; _k<(_height-_heightScreen); _k++ )); do
		_screen+="$_spaceScreen"
#	done

	tput reset
	tput civis
	
	# Configura a cor do fundo da tela
	#tput setab 7

	# Configura a cor da fonte
	#tput setaf 0

	ClearScreen

	_scoreX=$((((_width-80))/2)) # Guarda a Posição do Score na tela de acordo o tamanho do terminal aberto

}

# Função para limpar a tela
function ClearScreen {

	tput cup 0 0
	
	if [ $_color = "on" ]; then
		echo -ne "${_cor[1]}$_clearScreen"
	else
		echo -ne "\E[00;30;47m$_clearScreen"
	fi

	tput cup $_initY 0 # Seta o ponteiro para a linha em que o jogo será desenhado (renderizado)

}

# Função para montar a primeira fase do jogo
function LoadFase1 {
	
	_sizeFase=3000 # Tamanho da fase (largura)
	_btela=`printf "%${_sizeFase}s"` # Variavel com caracter espaço do tamanho da fase para montar o buffer da tela

	_tamQuad=100

	_flagDraw[4]="█          ███"	

	_flagX=2883
	_flagY=6

	# Vetor de localização dos inimigos definindo sua area de movimento
	_enemyX=(0 200 350 500 650 900 1490 1750 2030 2450 2780) 
	_enemyPathIni=(0 150 320 460 610 880 1480 1710 2000 2330 2700)
	_enemyPathFim=(0 250 420 560 710 980 1580 1810 2100 2480 2800)

	# Posicao das moedas no cenario
	_coin=(0 80 190 210 330 350 370 390 410 430 660 800 830 860 890 1010 1080 1150 1240 1260 1280 1370 1390 1410 1480 1500 1520 1540 1590 1650 1720 1810 1830 1850 1870 1890 2260 2290 2320 2350 2410 2540 2570 2600 2630)

	# Posicao dos blocos no cenario
	_bloco=(0 105 135 165 495 525 555 630 690 975 1035 1110 1305 1320 1335 1560 1620 1680 1785 1920 2010 2040 2070 2100 2130 2160 2385 2670 2760 2790)

	# Posicao das nuvens no cenario
	_nuvem=(0 30 220 290 450 580 750 930 1180 1430 1740 1950 2180 2450 2720 2830 2965)

	# Posição dos buracos na fase
	_buraco=(0 280 580 850 1420 1830 2300 2500)

	# Vetor para guardar a posição das monts na tela
	_mont=(0 35 150 210 390 520 740 810 960 1050 1180 1250 1360 1570 1780 1900 2060 2120 2350 2420 2580 2790) 

	_nuvem[0]=${#_nuvem[*]} # Define a quantidade de nuvens no cenario
	_nuvemY=(0) # Posicao em Y da nuvem no cenario
	_nuvemHeight=$_nuvem[0] # Altura da nuvem no cenario

	for (( _k=1; _k<_nuvem[0]; _k++ )); do
		_nuvemY[$_k]=2
	done

	_enemyX[0]=${#_enemyX[*]} # Define a constante da quantidade de (indices no vetor dos) inimigos
	_enemyWidth=16 # Largura do inimigo
	_enemyHeight=(0) # Altura do inimigo eh definido no indice[0] do sprite atual
	_enemyY=(0) # Posição do inimigo no eixo de y definido pelo piso e altura
	_enemyVelocX=(1) # Velocidade do inimigo
	_enemySprite=(0) # Define qual sprite do inimigo sera desenhado
	_enemyDead=(0) # vetor para definir inimigos vivos
	_aniEnemy=(0) # Define sprite de animacao do inimigo

	# Preenche o vetor com a posicao do quadrante dos inimigos
	for ((_k=1; _k<_enemyX[0]; _k++)); do

		_enemyVelocX[$_k]=${_enemyVelocX[0]}
		_enemySprite[$_k]=${_enemySprite[0]}
		_aniEnemy[$_k]=0
		_enemyDead[$_k]=0

	done

	_coin[0]=${#_coin[*]} # Define a constante da quantidade de moedas
	_coinWidth=10 # Largura da moeda
	_coinHeight=5 # Altura da moeda
	_coinY=(9) #posicao da moeda em y
	_coinQ=(0) #vetor para definir o quadrante das moedas
	_coinSprite=(0) #define sprite de animacao das moedas

	#Cria um vetor para o quadrante para checar as colisoes com as moedas
	for ((_k=1; _k<_coin[0]; _k++)); do

		_tmp=$((_coin[_k] / _coinWidth))
		_coinY[$_k]=${_coinY[0]}
		_coinQ[$_tmp]=$_k
		_coinSprite[$_k]=${_coinSprite[0]}

	done


	_blocoWidth=15 #largura do bloco
	_blocoY=8 #posicao do bloco em y
	_blocoHeight=7 #altura do bloco
	_blocoQ=(0) #vetor para definir o quadrante
	_bloco[0]=${#_bloco[*]}

	for ((_k=1; _k<_bloco[0]; _k++)); do

		_tmp=$((_bloco[_k] / _blocoWidth))
		_blocoQ[$_tmp]=$_k

	done

	_montWidth=30 #largura da montanha
	_mont[0]=${#_mont[*]}

	_buraco[0]=${#_buraco[*]}
	_buracoWidth=25

	#buffer da tela
	for (( _k=0; _k<=36; _k++ )); do	
		_fasel[$_k]="$_btela"
	done
	
	#monta o piso da fase no buffer
	_tmp=$((_sizeFase / 10))

	_fasel[37]=""
	_fasel[38]=""
	_fasel[39]=""

	#Coloca o piso na fase
	for (( _k=0; _k<_tmp; _k++ )); do

		_fasel[37]+="${_piso1}"
		_fasel[38]+="${_piso2}"
		_fasel[39]+="${_piso1}"

	done

	#desenha as nuvens no cenario
	for (( _k=1; _k<_nuvem[0]; _k++ )); do
		
		_tmpPos=${_nuvem[$_k]}

		_ind=${_nuvemY[$_k]}

		for (( _l=_ind; _l<_ind + _nuvemDraw[0]; _l++ )); do

			_tmp0=$(( _l - _ind + 1))			
			_tmp1=${#_nuvemDraw[$_tmp0]}

			_f=$(( _tmpPos + _tmp1  ))

			_fasel[$_l]="${_fasel[$_l]:0:$_tmpPos}${_nuvemDraw[$_tmp0]}${_fasel[$_l]:$_f}"
		done
	done

	#desenha os buracos na fase
#	for (( _k=1; _k<_buraco[0]; _k++ )); do
#		
#		_tmpPos=${_buraco[$_k]}
#
#		_f=$(( _tmpPos + 24 ))
#
#		_fasel[37]="${_fasel[37]:0:$_tmpPos}${_buracoDraw}${_fasel[37]:$_f}"
#		_fasel[38]="${_fasel[38]:0:$_tmpPos}${_buracoDraw}${_fasel[38]:$_f}"
#		_fasel[39]="${_fasel[39]:0:$_tmpPos}${_buracoDraw}${_fasel[39]:$_f}"
#	done

	#desenha as montanhas no buffer da fase
	for (( _k=1; _k<_mont[0]; _k++ )); do

		_montX=${_mont[$_k]}
		_tmp2=$(( _montX + _montWidth ))
		for (( _l=1; _l<=7; _l++ )); do
			_tmp=$((_l + 29 ))
			_fasel[$_tmp]="${_fasel[$_tmp]:0:$_montX}${_montDraw[$_l]}${_fasel[$_tmp]:$_tmp2}"
		done
	done

	#desenha os blocos na fase
	for (( _k=1; _k<_bloco[0]; _k++ )); do

		_blocoX=${_bloco[$_k]}
		_tmp2=$(( _blocoX + _blocoWidth ))

		_fasel[$((_blocoY))]="${_fasel[$((_blocoY))]:0:$_blocoX}${_blocoDraw[0]}${_fasel[$((_blocoY))]:$_tmp2}"
		_fasel[$((_blocoY+1))]="${_fasel[$((_blocoY+1))]:0:$_blocoX}${_blocoDraw[1]}${_fasel[$((_blocoY+1))]:$_tmp2}"
		_fasel[$((_blocoY+2))]="${_fasel[$((_blocoY+2))]:0:$_blocoX}${_blocoDraw[1]}${_fasel[$((_blocoY+2))]:$_tmp2}"
		_fasel[$((_blocoY+3))]="${_fasel[$((_blocoY+3))]:0:$_blocoX}${_blocoDraw[1]}${_fasel[$((_blocoY+3))]:$_tmp2}"
		_fasel[$((_blocoY+4))]="${_fasel[$((_blocoY+4))]:0:$_blocoX}${_blocoDraw[1]}${_fasel[$((_blocoY+4))]:$_tmp2}"
		_fasel[$((_blocoY+5))]="${_fasel[$((_blocoY+5))]:0:$_blocoX}${_blocoDraw[1]}${_fasel[$((_blocoY+5))]:$_tmp2}"
		_fasel[$((_blocoY+6))]="${_fasel[$((_blocoY+6))]:0:$_blocoX}${_blocoDraw[0]}${_fasel[$((_blocoY+6))]:$_tmp2}"
	done

	#desenha moedas na fase
#	for (( _k=1; _k<_coin[0]; _k++ )); do

#		_coinX=${_coin[$_k]}
#		_tmp2=$(( _coinX + _coinWidth ))
#		for (( _l=1; _l<=5; _l++ )); do
#			_tmp=$((_l+8))
#			_fasel[$_tmp]="${_fasel[$_tmp]:0:$_coinX}${_coinDraw[$_l]}${_fasel[$_tmp]:$_tmp2}"
#		done
#	done

	#desenha o castelo na fase
	for (( _k=1; _k<=_castle[0]; _k++ )); do

		((_tmp = _k + 5))
		_tmpL=${#_castle[$_k]}
		_tmpI=$((_sizeFase-120))
		_tmpF=$((_tmpI + _tmpL))

		_fasel[$_tmp]="${_fasel[$_tmp]:0:$_tmpI}${_castle[$_k]}${_fasel[$_tmp]:$_tmpF}"
	done

}

# funcao para desenhar os buracos na fase
function DrawBuraco {

	_ubound=${_buraco[0]}

	for (( _k=1; _k < _ubound; _k++ )); do #laco para verificar cada inimigo

		#verifica se o buraco esta visivel na camera
		if [ $((_buraco[_k] + _buracoWidth)) -ge $_cameraX ] && [ ${_buraco[$_k]} -le $((_cameraX + _width)) ]; then 

			_buracoX=$(( _buraco[_k] + _edgeWidth - _cameraX ))
			_buracoL=$(( _buracoX + _buracoWidth ))

			_tmp=${_canvasC[0]}

			for (( _l=37; _l<40; _l++ )); do
				_canvas[$_l]="${_canvas[$_l]:0:$((_buracoX-2))}${_buracoDraw}${_canvas[$_l]:$((_buracoL+2))}"

				if [ $_color = "on" ]; then
					_tmp=${_canvasC[0]}
					((_tmp++))
					_canvasC[$_tmp]=${_cor[2]}
					if [ $((_buracoX - _edgeWidth)) -lt 0 ]; then
						_canvasP[$_tmp]=$((_width * _l))
					else
						_canvasP[$_tmp]=$(( (_width * _l) + _buracoX - _edgeWidth ))
					fi
					((_tmp++))
					_canvasC[$_tmp]=${_cor[3]}
					if [ $((_buracoL - _edgeWidth)) -gt $_width ]; then
						_canvasP[$_tmp]=$(( _width * (_l+1) ))
					else
						_canvasP[$_tmp]=$(( (_width * _l) + _buracoL - _edgeWidth ))
					fi

					_canvasC[0]=$_tmp

				fi

			done


		fi
	done

}

# Funcao para montar o buffer de fundo da tela a partir da cordenada do jogador
function MontaCanvas {

	#Limpa o buffer para posicionar a camera na tela da primeira fase
	#_canvas=""

	#verifica se a posicao do jogador é menor do que o meio do terminal
	if [ $_jogX -lt $_widthMid ]; then

		_cameraX=0 #zera a posicao da camera

	else 
		if [ $_jogX -ge $((_sizeFase - _widthMid)) ]; then #se posicao do jogador passou do meio do terminal

			_cameraX=$((_sizeFase - _width)) #fixa a camera no final da fase

		else

			_cameraX=$((_jogX - _widthMid)) #fixa o jogador no meio da camera
		fi
	fi

	#gera o buffer da tela de acordo com a posicao da camera
	 for (( _k=0; _k<_heightScreen; _k++ )); do

		_f=$(( _cameraX + _width -1))

		_canvas[$_k]="${_edgeScreen}${_fasel[$_k]:$_cameraX:$_width}${_edgeScreen}"

	done


}

#Sair do jogo para o terminal
function Sair {

	#Restaura configurações do terminal
	stty $_terminal
	
	#Retorna o ponteiro que pisca na tela
	tput cnorm

	#Volta as cores ao normal
	tput sgr0

	#Limpa a tela
	tput reset

	#Restaura o terminal ao seu padrao	
	#stty sane
	
	# Verifica se ocorreu algum erro e imprime na tela do terminal
	if [ "$_erro" != "" ]; then
		echo -e $_erro
	fi
	
	# termina o programa	
	exit
}

#inicializa as variaveis para comecar o jogo
function InitGame {

	_score=0 #zera o score atual

#	_coins=0 #Zera as moedas pega em jogo anterior

	_jogLife=3 #variavel com valor inicial de vidas para o jogo

	Splash #Função para exibir as vidas do jogador
	
}

# funcao para somar score e salvar top score
function Score {

	((_score+=$1))

	if [ $_score -ge $_topScore ]; then
		_topScore=$_score
		SaveSettings
	fi	

}

#função para salvar configurações quando ocorrer mudanças
function SaveSettings {

	echo "_topScore=$_topScore">.settings
	echo "_sound=$_sound">>.settings
	echo "_color=$_color">>.settings

}
#Função para exibir as vidas do jogador
function Splash {

	#Seta o nome da tela atual(estado do jogo)
	_screenGame="SPLASH"

	LoadColors

	#Registra Coordenadas iniciais do jogador
	_jogX=0
	_jogY=0
	_velocY=0
	_velocX=0

	_jogDead=false #Controla se o jogador morreu

	# guarda qual sprite do personagem sera exibido
	_jogAni=0 #controla a animacao de sprite para dar sensacao mais real do andar
	_jogSprite=0

	#lado do jogador (Sprite) d=direito e=esquerdo
	_jogSide="D"

	#Preenche o buffer com a tela do Splash
	for (( _y=0; _y<12; _y++ )); do

		_canvas[$_y]="${_edgeScreen}${_spaceScreen}${_edgeScreen}"

	done

	_canvas[12]="${_edgeScreen}${_spaceIni}                              █████                                             ${_spaceFim}${_edgeScreen}"
	_canvas[13]="${_edgeScreen}${_spaceIni}                             █░░░░M███                                          ${_spaceFim}${_edgeScreen}"
	_canvas[14]="${_edgeScreen}${_spaceIni}                            █░░░░░░░░░█                                         ${_spaceFim}${_edgeScreen}"
	_canvas[15]="${_edgeScreen}${_spaceIni}                            ███  █ ███                                          ${_spaceFim}${_edgeScreen}"
	_canvas[16]="${_edgeScreen}${_spaceIni}                           █  ██ █    █       X     0${_jogLife}                          ${_spaceFim}${_edgeScreen}"
	_canvas[17]="${_edgeScreen}${_spaceIni}                           █  ██  █   █                                         ${_spaceFim}${_edgeScreen}"
	_canvas[18]="${_edgeScreen}${_spaceIni}                            ██   █████                                          ${_spaceFim}${_edgeScreen}"
	_canvas[19]="${_edgeScreen}${_spaceIni}                             ██     █                                           ${_spaceFim}${_edgeScreen}"
	_canvas[20]="${_edgeScreen}${_spaceIni}                               █████                                            ${_spaceFim}${_edgeScreen}"

	for (( _y=21; _y<_heightScreen; _y++ )); do

		_canvas[$_y]="${_edgeScreen}${_spaceScreen}${_edgeScreen}"

	done
	
	Render #chama função Render

	LoadFase1 #Carrega a tela da primeira fase para o buffer

	sleep 1 #adormece o script por 1 segundos

	#Toca som de fundo tema	
	Play "background"

	#Seta o nome da tela atual(posicao no jogo)
	_screenGame="GAME"

	_timeIni=$SECONDS #set variavel com tempo de segundo do sistema para controlar tempo no jogo
}

# função para desenha gameover na tela
function GameOver {

	# seta que o jogo na tela de game over
	_screenGame="GAMEOVER"

	LoadColors

	#Preenche o buffer com a tela do Splash
	for (( _y=0; _y<13; _y++ )); do

		_canvas[$_y]="${_edgeScreen}${_spaceScreen}${_edgeScreen}"

	done

	#desenho do gameover

	_canvas[13]="${_edgeScreen}$_spaceIni  ████    ████   ██   ██  ██████           ████   ██  ██  ██████  █████     ██  $_spaceFim${_edgeScreen}" 
	_canvas[14]="${_edgeScreen}$_spaceIni ██      ██  ██  ███ ███  ██              ██  ██  ██  ██  ██      ██  ██    ██  $_spaceFim${_edgeScreen}" 
	_canvas[15]="${_edgeScreen}$_spaceIni ██ ███  ██████  ██ █ ██  ████            ██  ██  ██  ██  ████    █████     ██  $_spaceFim${_edgeScreen}" 
	_canvas[16]="${_edgeScreen}$_spaceIni ██  ██  ██  ██  ██   ██  ██              ██  ██   ████   ██      ██  ██        $_spaceFim${_edgeScreen}"   
	_canvas[17]="${_edgeScreen}$_spaceIni  ████   ██  ██  ██   ██  ██████           ████     ██    ██████  ██  ██    ██  $_spaceFim${_edgeScreen}"  


	for (( _y=18; _y<_heightScreen; _y++ )); do

		_canvas[$_y]="${_edgeScreen}${_spaceScreen}${_edgeScreen}"

	done

	Render #chama função Render

	sleep 4 #adormece o script por segundos

	LoadMenu
}

# função para desenhar a tela de GameWin
function GameWin {

	# seta que o jogo na tela de game over
	_screenGame="GAMEWIN"

	LoadColors

	#Preenche o buffer com a tela do Splash
	for (( _y=0; _y<10; _y++ )); do

		_canvas[$_y]="${_edgeScreen}${_spaceScreen}${_edgeScreen}"

	done

	#desenho do fim do jogo WIN

_canvas[10]="${_edgeScreen}${_spaceIni}      █████    ████   █████    ████   █████   ██████  ██  ██   ████     ██      ${_spaceFim}${_edgeScreen}" 
_canvas[11]="${_edgeScreen}${_spaceIni}      ██  ██  ██  ██  ██  ██  ██  ██  ██  ██  ██      ███ ██  ██        ██      ${_spaceFim}${_edgeScreen}" 
_canvas[12]="${_edgeScreen}${_spaceIni}      █████   ██████  █████   ██████  █████   ████    ██ ███   ████     ██      ${_spaceFim}${_edgeScreen}" 
_canvas[13]="${_edgeScreen}${_spaceIni}      ██      ██  ██  ██  ██  ██  ██  ██  ██  ██      ██  ██      ██            ${_spaceFim}${_edgeScreen}"   
_canvas[14]="${_edgeScreen}${_spaceIni}      ██      ██  ██  ██  ██  ██  ██  █████   ██████  ██  ██   ████     ██      ${_spaceFim}${_edgeScreen}"  
_canvas[15]="${_edgeScreen}${_spaceScreen}${_edgeScreen}"
_canvas[16]="${_edgeScreen}${_spaceScreen}${_edgeScreen}"
_canvas[17]="${_edgeScreen}${_spaceScreen}${_edgeScreen}"
_canvas[18]="${_edgeScreen}${_spaceIni} TRABALHO EM SHELL SCRIPT                                                      ${_spaceFim}${_edgeScreen}"
_canvas[19]="${_edgeScreen}${_spaceScreen}${_edgeScreen}"
_canvas[20]="${_edgeScreen}${_spaceIni} FATEC CARAPICUIBA                                                             ${_spaceFim}${_edgeScreen}"
_canvas[21]="${_edgeScreen}${_spaceScreen}${_edgeScreen}"
_canvas[22]="${_edgeScreen}${_spaceIni} DISCIPLINA LSO (LABORATORIO DE SISTEMAS OPERACIONAIS)                         ${_spaceFim}${_edgeScreen}"
_canvas[23]="${_edgeScreen}${_spaceScreen}${_edgeScreen}"
_canvas[24]="${_edgeScreen}${_spaceIni} PROF. RUBENS                                                                  ${_spaceFim}${_edgeScreen}"
_canvas[25]="${_edgeScreen}${_spaceScreen}${_edgeScreen}"
_canvas[26]="${_edgeScreen}${_spaceIni} ALUNO DORIEDSON ALVES GALDINO DE OLIVEIRA                                     ${_spaceFim}${_edgeScreen}"
_canvas[27]="${_edgeScreen}${_spaceScreen}${_edgeScreen}"
_canvas[28]="${_edgeScreen}${_spaceIni} ALUNO VITOR AUGUSTO ANDRIOLI                                                  ${_spaceFim}${_edgeScreen}"
_canvas[29]="${_edgeScreen}${_spaceScreen}${_edgeScreen}"
_canvas[30]="${_edgeScreen}${_spaceIni} ALUNO THIAGO ANDRE SILVA                                                      ${_spaceFim}${_edgeScreen}"
_canvas[31]="${_edgeScreen}${_spaceScreen}${_edgeScreen}"


	for (( _y=32; _y<_heightScreen; _y++ )); do

		_canvas[$_y]="${_edgeScreen}${_spaceScreen}${_edgeScreen}"

	done

	Render #chama função Render

	sleep 4 #adormece o script por segundos

	read -n1

	LoadMenu
}

#Carrega a tela do menu para o buffer
function LoadMenu {

	if [ $_musicId ]; then
		Stop $_musicId #Mata o processo da musica de fundo
	fi

	#Seta o nome da tela atual(posicao no jogo)
	_screenGame="MENU"

}

#monta tela do menu no canvas
function MontaMenu {

	#Limpa o buffer para preencher com a tela do menu
	#_canvas=""

	#Preenche o buffer com a tela menu
	for (( _y=0; _y<26; _y++ )); do
		
		_canvas[$_y]="${_edgeScreen}${_spaceIni}${_menu[$_y]}${_spaceFim}${_edgeScreen}"

	done

	_tmpi=$((36+12-${#_topScore}))
	_canvas[26]="${_edgeScreen}${_spaceIni}${_menu[26]:0:$_tmpi}${_topScore}${_menu[26]:60}${_spaceFim}${_edgeScreen}"

	for (( _y=27; _y<_heightScreen; _y++ )); do
		
		_canvas[$_y]="${_edgeScreen}${_spaceIni}${_menu[$_y]}${_spaceFim}${_edgeScreen}"

	done

}

function LoadColors {

	if [ $_color = "off" ]; then
		return
	fi

	# vetor para guardar as cores do cenario
	_canvasC=(0) #guarda a cor
	_canvasP=(0) #guarda a posicao da cor

	_tmp=0

	((_tmp++))
	_canvasC[$_tmp]=${_cor[1]}
	_canvasP[$_tmp]=0

	((_tmp++))
	_canvasC[$_tmp]=${_cor[2]}
	_canvasP[$_tmp]=$((_width * 2))

	case $_screenGame in

	"MENU")
		_tmp2=${#_spaceIni}
		for ((_k=5; _k<18; _k++)); do
			((_tmp++))
			_canvasC[$_tmp]=${_cor[0]}
			_canvasP[$_tmp]=$(((_width * _k) + _tmp2 + 15))
			((_tmp++))
			_canvasC[$_tmp]=${_cor[2]}
			_canvasP[$_tmp]=$(((_width * _k) + _tmp2 + 65))
		done

		((_tmp++))
		_canvasC[$_tmp]=${_cor[3]}
		_canvasP[$_tmp]=$((_width * 37))
		;;

	"GAME"|"DEAD"|"WIN"|"WINPOINT") 
		((_tmp++))
		_canvasC[$_tmp]=${_cor[3]}
		_canvasP[$_tmp]=$((_width * 37))
		;;

	esac

	_canvasC[0]=$_tmp

}

#Desenha o Jogador no buffer da tela
function DrawJogador {

	#Calcula a posição inicial do desenho do jogador no buffer da tela
	_tmpJogX=$((_jogX - (_cameraX - _edgeWidth)))
	_tmpIni=1

	if [ $((_jogY + _jogHeight -1)) -gt 39 ]; then
		_tmpJogHeight=$(( 40 - _jogY ))
	elif [ $_jogY -lt 0 ]; then
		_tmpJogHeight=$(( _jogHeight + _jogY ))
		_tmpIni=$((-_jogY +1))
	else
		_tmpJogHeight=$_jogHeight
	fi

	#Laço para desenhar o jogador
	for (( _l=_tmpIni; _l<=_tmpJogHeight; _l++ )); do

		#Pega pŕoxima variável(linha) do desenho do jogador
		_tmp="_mario${_jogSide}${_jogSprite}[$_l]"

		#Lê o valor da variável como nome de outro variavel
		_tmp="${!_tmp}"

		#Calcula o tamanho restante da buffer da tela para recorte
		_tmpf=$((_tmpJogX+${#_tmp}))

		#Desenha a linha do personagem no buffer da tela
		#_screen="${_screen:0:$_posIniJog}${_tmp}${_screen:$_resto}"
		_tmpJogY=$(( _jogY+_l-1))		
		_canvas[$_tmpJogY]="${_canvas[$_tmpJogY]:0:$_tmpJogX}${_tmp}${_canvas[$_tmpJogY]:$_tmpf}"

	done
}

#função para desenhar o score no topo do buffer da tela
function DrawScore {

	# Gera novo buffer para tela
	#_screen="$_canvas"
	
	#posicao das linhas temporariamente
	_tmp=0

	#posiciona e imprime o title score
	#_screen="${_screen:0:$_tmp}${_spaceIni}${_scoreTitle0}${_spaceFim}${_screen:$((_tmp + _width))}"
	_canvas[0]="${_edgeScreen}${_spaceIni}${_scoreTitle0}${_spaceFim}${_edgeScreen}"

	_tmpScore=${#_score}
	_tmpScorei=$((11 - _tmpScore))

	_tmpCoin=${#_coins}
	_tmpCoini=$((21 - _tmpCoin))

	_tmpTime=${#_time}
	_tmpTimei=$(( 37 - _tmpTime ))

	((_tmp+=_width))
	_canvas[1]="${_edgeScreen}${_spaceIni}${_scoreTitle1:0:$_tmpScorei}${_score}${_scoreTitle1:11:${_tmpCoini}}${_coins}${_scoreTitle1:32:$_tmpTimei}${_time}${_scoreTitle1:69}${_spaceFim}${_edgeScreen}"

	# gera o texto que exibe o fps e posiciona na tela
	_texto="[s]sound:$_sound [c]color:$_color LPS:$_lps"

#	_i=$((39 * _width))
	_l=${#_texto}

	# posiciona e imprime o texto fps na _screen
	_pos=$((39))
	_canvas[$_pos]="${_edgeScreen}${_texto}${_canvas[$_pos]:$((_l + _edgeWidth))}${_edgeScreen}"

}

#Desenha o buffer no terminal
function Render {
	
	# se jogo esta em andamento chama função para montar o buffer da tela de acordo a posição da camera na fase	
	case $_screenGame in
	
	"GAME"|"DEAD"|"WIN"|"WINPOINT")
		MontaCanvas;;

	"MENU")
		MontaMenu;;

	esac


	case $_screenGame in

		"SPLASH"|"GAMEOVER"|"GAMEWIN")
			DrawScore #desenha o score no topo da tela
			;;

		"MENU")
			DrawScore #desenha o score no topo da tela
			_temp=0 #variavel nao utilizada para nao deixar o case vazio
			;;

		"GAME"|"DEAD"|"WIN"|"WINPOINT")
			DrawBuraco #desenha buracos na fase
			DrawScore #desenha o score no topo da tela
			DrawCoin #desenha as moedas se existir
			DrawEnemy #desenha o inimigo se existir
			DrawFlag #desenha a bandeira do mastro
			DrawJogador #Desenha o jogador
			;;

	esac

	_screen=""

	for (( _k=0; _k<_heightScreen; _k++ )); do
		_canvas[$_k]="${_canvas[$_k]:$_edgeWidth:$_width}"
		_screen+="${_canvas[$_k]}"
	done

	if [ $_color = "on" ]; then

#echo "${_canvasC[*]}"

		BubbleSort

#		QuickSort 1 ${_canvasC[0]}


#		_tmpSize=$(( _width * _height / 10 ))

#		for (( _k=_tmpSize; _k>0; _k-- )); do
#			if [ ! -z ${_canvasP[$_k]} ]; then
				#_screen="${_screen:0:${_canvasP[$_k]}}${_canvasC[$_k]}${_screen:${_canvasP[$_k]}}"
#			fi
#		done

		for (( _k=_canvasC[0]; _k>0; _k-- )); do
			_screen="${_screen:0:${_canvasP[$_k]}}${_canvasC[$_k]}${_screen:${_canvasP[$_k]}}"
		done
	fi

	#Desenha a cena atual do jogo no terminal
	echo -ne "$_screen" 

	tput cup $_initY 0 #Posiciona o ponteiro na tela para desenhar o buffer 

}

function QuickSort {

	local _ini=$1
	local _fim=$2
	local _pivo=${_canvasP[$(( (_ini + _fim ) / 2 ))]}

	while [ $_ini -lt $_fim ]; do

		while [ ${_canvasP[$_ini]} -lt $_pivo ]; do
			((_ini++))
		done

		while [ ${_canvasP[$_fim]} -gt $_pivo ]; do
			((_fim--))
		done

		if [ $_ini -le $_fim ]; then
			local _aux=${_canvasP[$_ini]}
			_canvasP[$_ini]=${_canvasP[$_fim]}
			_canvasP[$_fim]=$_aux

			local _aux=${_canvasC[$_ini]}
			_canvasC[$_ini]=${_canvasC[$_fim]}
			_canvasC[$_fim]=$_aux

			((_ini++))
			((_fim--))
		fi

		if [ $_fim -gt $1 ]; then
			QuickSort $1 $_fim
		fi

		if [ $_ini -lt $2 ]; then
			QuickSort $_ini $2
		fi
	done

}

#ordena o vetor de cores da menor posicao para maior
function BubbleSort {

	for (( _k=(_canvasC[0]); _k>1; _k-- )); do

		for (( _l=1; _l<_k; _l++ )); do
			
			(( _tmp= _l + 1 ))


			if [ $((_canvasP[$_l])) -gt $((_canvasP[$_tmp])) ]; then

				_tmpV=${_canvasP[$_tmp]} 
				_canvasP[$_tmp]=${_canvasP[$_l]} 
				_canvasP[$_l]=$_tmpV

				_tmpC=${_canvasC[$_tmp]} 
				_canvasC[$_tmp]=${_canvasC[$_l]} 
				_canvasC[$_l]=$_tmpC

			fi

		done

	done

}

# funcao para desenhar as moedas
function DrawCoin {

	((_tmp1=_cameraX / _coinWidth))
	((_tmp2=(_cameraX + _width) / _coinWidth))

	for (( _k=_tmp1; _k<=_tmp2; _k++)); do

		_tmpCoin=${_coinQ[$_k]} #pega a posicao do indice do vetor das moedas se existir


		if [ $_k -eq 0 ] || [ -z $_tmpCoin ]; then #verifica se o indíce do quadrante não é zero e se existe moeda no quadrante
			continue
		else

			_coinX=${_coin[$_tmpCoin]} #pega a posicao x da moeda

			if [ $_coinX -gt 0 ]; then #se existir moeda desenha ela

				((_coinX-=(_cameraX-_edgeWidth)))

				((_coinSprite[_tmpCoin]++))

				if [ ${_coinSprite[$_tmpCoin]} -eq 6 ]; then
					_coinSprite[$_tmpCoin]=0
				fi

				((_tmpSp=_coinSprite[_tmpCoin]/2))

				#Laço para desenhar a moeda
				for (( _l=1; _l<=_coinHeight; _l++ )); do

					#Pega pŕoxima variável(linha) do desenho do jogador
					_tmpS="_coinDraw${_tmpSp}[$_l]"

					#Lê o valor da variável como nome de outro variavel
					_tmpS="${!_tmpS}"

					#Calcula o tamanho restante da buffer da tela para recorte
					_tmpf=$((_coinX + _coinWidth))

					#Desenha a linha da coin no buffer da tela
					_tmpCoinY=$(( _coinY[_tmpCoin] + _l -1))		

					_canvas[$_tmpCoinY]="${_canvas[$_tmpCoinY]:0:$_coinX}${_tmpS}${_canvas[$_tmpCoinY]:$_tmpf}"

					if [ $_color = "on" ]; then

						_tmp=${_canvasC[0]}
						((_tmp++))
						_canvasC[$_tmp]=${_cor[4]}

						if [ $((_coinX - _edgeWidth)) -lt 0 ]; then
							_canvasP[$_tmp]=$((_width * _tmpCoinY))
						else
							_canvasP[$_tmp]=$(( (_width * _tmpCoinY) + _coinX - _edgeWidth ))
						fi

						((_tmp++))
						_canvasC[$_tmp]=${_cor[2]}
						if [ $((_tmpf - _edgeWidth)) -gt $_width ]; then
							_canvasP[$_tmp]=$(( _width * (_tmpCoinY+1) ))
						else
							_canvasP[$_tmp]=$(( (_width * _tmpCoinY) + _tmpf - _edgeWidth ))
						fi

						_canvasC[0]=$_tmp

					fi

				done

			fi
		fi

	done

}

# funcao para desenhar a bandeira no mastro
function DrawFlag {

	if [ $_flagX -lt $(( _cameraX + _width )) ]; then

		for (( _k=1; _k<=_flagDraw[0]; _k++ )); do

			#Calcula o tamanho restante da buffer da tela para recorte
			_tmpL=${#_flagDraw[$_k]}
			_tmpY=$(( _flagY + _k -1 ))
			_tmpX=$(( _flagX - _cameraX + _edgeWidth ))
			_tmpF=$(( _tmpX + _tmpL ))


			#Desenha a linha do inimigo no buffer da tela
			_canvas[$_tmpY]="${_canvas[$_tmpY]:0:$_tmpX}${_flagDraw[$_k]}${_canvas[$_tmpY]:$_tmpF}"

		done

		
	
	fi

}

#função para desenhar o inimigo se existir
function DrawEnemy {

	_ubound=${_enemyX[0]}

	for (( _k=1; _k < _ubound; _k++ )); do #laco para verificar cada inimigo

		#verifica se o path do inimigo esta visivel na camera
		if [ $((_enemyX[_k] + _enemyWidth)) -ge $_cameraX ] && [ ${_enemyX[$_k]} -le $((_cameraX + _width)) ] && [ ${_enemySprite[$_k]} -le 6 ]; then 

			_tmpY="_gompa${_enemySprite[$_k]}[0]" #Pega o sprite do inimigo
			_tmpY="${!_tmpY}"

			#Calcula a posição inicial do desenho do inimigo no buffer da tela
			_tmpEnemyY=$((_enemyY[_k])) #$((37 - _tmpY))
			_tmpEnemyX=$(( _enemyX[_k] - (_cameraX - _edgeWidth)))

			#Laço para desenhar o inimigo
			for (( _l=1; _l<=_tmpY; _l++ )); do

				_tmpE="_gompa${_enemySprite[$_k]}[$_l]" #Pega o sprite do inimigo
				_tmpE="${!_tmpE}"

				#Calcula o tamanho restante da buffer da tela para recorte
				_tmpL=${#_tmpE}
				_tmpf=$(( _tmpEnemyX + _tmpL ))

				#Desenha a linha do inimigo no buffer da tela
				_canvas[$_tmpEnemyY]="${_canvas[$_tmpEnemyY]:0:$_tmpEnemyX}${_tmpE}${_canvas[$_tmpEnemyY]:$_tmpf}"

				#Muda a posição inicial de plotagem para a próxima linha do inimigo
				((_tmpEnemyY++))
			done
		fi
	done

}

#Função para ouvir o teclado
function ListenKey {

	# ouve as teclas pressionadas pelo teclado
	_key=$(dd bs=3 count=1 2>/dev/null)	

#read -n1 -t 0.001 _key

	# eliminar os caracters especias de quando as setas direcionais forem pressionadas
#	while [ "$_key" = "^" ] || [ "$_key" = "[" ]; do

#		read -n1 -t 0.001 _key
#	done

	#Verifica as teclas pressionadas
	case $_key in

	$KEY_ENTER) #tecla ENTER
		case $_screenGame in

		"MENU")
			InitGame;; #Inicia o jogo

		esac
		;;


	$KEY_ESC) #tecla ESC  
		case $_screenGame in

		"MENU")
			Sair ;; #Termina o programa

		"GAME")
			LoadMenu;; #Carrega a tela de menu

		esac
		;;
	
	$KEY_UP) #Seta para cima
		case $_screenGame in

		"GAME")
			#_clearBuffer=true
			#Verifica se velocidade de y é = 0 e se o personagem esta no piso entao libera para pulo
			if [ $_velocY -eq 0 ] && [ $((_jogY+_jogHeight)) -eq $((_piso)) ]; then
				Play "jump" #Toca audio do pulo
				#_jogSprite=2 #Sprite do jogador pulando
				((_velocY=-6)) #Define velocidade do pulo
			fi
			;;
		esac
		;;

	$KEY_RIGHT) # Pressionado a seta para direita 
		case $_screenGame in

		"GAME")
			#_clearBuffer=true
			#_jogSide=d #lado do jogador a desenhar
			((_velocX=4)) #Velocidade do jogador em X
			;;
		esac
		;;

	$KEY_LEFT) # Pressionado a seta para esquerda
		case $_screenGame in

		"GAME")
			#_clearBuffer=true
			#_jogSide=e #lado do jogador a desenhar
			((_velocX=-4)) #velocidade do jogador em X
			;;
		esac
		;;

	"s")
		if [ $_sound = "off" ] ; then
			_sound="on"

			if [ $_screenGame = "GAME" ]; then
				Play "background"
			fi
		else
			_sound="off"

			if [  $_musicId ]; then
				Stop $_musicId #para o processo da musica de fundo
			fi
		fi
		SaveSettings
		;;

	"c")
		if [ $_color = "on" ]; then		
			_color="off"
		else
			_color="on"
		fi
		SaveSettings
		ClearScreen
		;;

	esac

	
	#Se for capturado alguma tecla antes entao limpa o buffer para caso de segurar a tecla pressionada	
	#if [ $_clearBuffer = true ] ; then
	#	read -n100 -t0.001 _discard
	#	_clearBuffer=false
	#fi
}

#Função para verificar quantos loops por segundo o jogo está conseguindo rodar
function FPS {
	# incrementa 1 na variável quadros	
	((_quadros++))

	# Guarda o nanosegundo atual do relógio do sistema	
	_tempo2N=$((10#`date +%N`))
	
	# verifica se passou 1 segundo desde o início da contagem e coloca os quadros contados na
	# variável _fps para exibição posteriormente
#	if [ $((SECONDS - _tempoS)) -gt 0 ] ; then


		#Guarda o segundo atual desde quando o terminal foi aberto	
#		_tempoS=$SECONDS


#	fi
	
	#Calcula a diferenca entre agora e a ultima leitura em nanosegundo
	_tmp=$((_tempo2N-_tempoN))

	#corrige a diferenca pra positivo se for negativo a cada segundo que se passa
	if [ $_tmp -lt 0 ]; then
		((_tmp+=1000000000))


		if [ $_quadroRender -gt 5 ]; then		
			#Atualiza a taxa de quadros por segundo
			_lps=$_quadros
			_fps=$_quadroRender

			#Zera o contador de quadros para comecar novamente
			_quadros=0

			_quadroRender=0


		fi

	fi

	#a cada 1 decimo de segundo libera para cálculo de movimento do personagem e cenario
	if [ $_tmp -ge 100000000 ]; then
		((_quadroRender++))

		_tempoN=$_tempo2N
		_next=true

		TerminalSize

		case $_screenGame in

		"GAME") #opção para reduzir um segundo no relógio de tempo do jogo
	
			_time=$(( _timeGame - (( SECONDS - _timeIni )) ))

			if [ $_time -eq 30 ]; then
				if [ $_quadroRender -eq 5 ]; then
					Play "timewarning"
				fi

			elif [ $_time -eq 27 ]; then
				if [ $_quadroRender -eq 5 ]; then
					Play "background"
				fi

			elif [ $_time -eq 0 ]; then # se tempo acabou o personagem morre
	
				Dead "time"
				_velocY=-5
				_jogSprite=0
				_jogSide="F"

			fi
			;;
		esac

	fi
}


#Funcao para calcular o movimento do jogador
function Jogador {

	case $_screenGame in

	"WINPOINT")
		if [ $_time -gt 0 ]; then
			Score 10
			((_time--))
			Play "point"
		else
			GameWin
		fi
		;;

	"WIN")

		# Controla o movimento na vertical(pulo) e faz colisao com o piso do cenario
		if [ $_velocY -ne 0 ] || [ $((_jogY - 1 + _jogHeight)) -ne $((_piso - 1)) ]; then	

			_jogSprite="2"
			((_velocY+=_gravidade)) #incremento de velocidade pela gravidade
			((_jogY+=_velocY)) #incremento de posição vertical do personagem pela velocidade
			((_flagY=_jogY))
			#verifica se o personagem atravessou o piso
			if [ $((_jogY - 1 + _jogHeight)) -ge $((_piso)) ]; then
				_jogAni=0
				_jogSprite="0"
				((_jogY=_piso - _jogHeight)) #nao houve colisao entao posiciona o personagem no piso
				_velocY=0 #zera a velocidade de y
				Play "worldcleared"
			fi
		elif [ $_jogX -lt 2927 ]; then
			((_jogX++))
			#Animacao do Personagem
			((_jogAni++))

			if [ $_jogAni -eq 2 ]; then
				_jogSprite=0
				_jogAni=0
			else
				_jogSprite=1
			fi
		else
			_jogX=3001
			_screenGame="WINPOINT"
		fi
		;;

	"GAME"|"DEAD") # se jogo em fase ou personagem morto processa movimento do personagem
		if [ $_jogDead = true ]; then
			((_velocY+=_gravidade))
			((_jogY+=_velocY))
			if [ $_jogY -gt 50 ]; then
				if [ $_jogLife -eq 0 ]; then # se acabou as vidas do personagem termina jogo e volta para o menu principal
					sleep 1
					GameOver
				else # se não mostra vidas restante do jogador
					sleep 2
					Splash
				fi
			fi

			return
		fi

		# Controla o movimento na horizontal do personagem e faz colisao com os limites do cenario
		if [ $_velocX -ne 0 ]; then	
			
			if [ $_velocX -gt 0 ]; then
				((_jogX+=4)) # =_velocX)) #Movimenta o Personagem
			else
				((_jogX-=4))
			fi
			if [ $_velocX -lt 0 ]; then

				_jogSide="E"

				#Colisao com o comeco e o fim da fase
				if [ $_jogX -lt 0 ]; then
					_jogX=0
				fi
				
				#se personagem toca o piso a velocidade do persogem em x sofre alteração
				if [ $_velocY -eq 0 ]; then
					((_velocX++))
				fi

			else
				#determina o sprite da posicao que o personagem anda
				_jogSide="D"

				#colisao  com o fim do cenario
				if [ $_jogX -gt $((_sizeFase - _jogWidth)) ]; then
					_jogX=$((_sizeFase - _jogWidth))
				fi

				#se personagem toca o piso a velocidade do persogem em x sofre alteração
				if [ $_velocY -eq 0 ]; then
					((_velocX--))
				fi


			fi
				
			#Animacao do Personagem
			((_jogAni++))

			if [ $_jogAni -eq 2 ]; then
				_jogSprite=0
				_jogAni=0
			else
				_jogSprite=1
			fi
		else
			_jogAni=0
			_jogSprite=0
		fi	

		# Controla o movimento na vertical(pulo) e faz colisao com o piso do cenario
		if [ $_velocY -ne 0 ] || [ $((_jogY - 1 + _jogHeight)) -ne $((_piso - 1)) ]; then	

			_jogSprite="2"
			((_velocY+=_gravidade)) #incremento de velocidade pela gravidade
			((_jogY+=_velocY)) #incremento de posição vertical do personagem pela velocidade

			#verifica se o personagem atravessou o piso
			if [ $((_jogY - 1 + _jogHeight)) -ge $((_piso)) ]; then
				_jogAni=0
				_jogSprite="0"

				ColisaoBuraco # Verifica se houve colisao com buraco
				if [ $? -eq 0 ]; then
					((_jogY=_piso - _jogHeight)) #nao houve colisao entao posiciona o personagem no piso
					_velocY=0 #zera a velocidade de y
				fi

			fi
		else
			ColisaoBuraco # Verifica se houve colisao com buraco
	
		fi

	;;

	esac

	if [ $_screenGame = "GAME" ]; then
		
		#verifica qual sentido o personagem está andando para dar prioridade a colisao do bloco da esquerda ou direita quando colidir com dois
		if [ $_jogSide = "D" ]; then
			_tmp2=$(( _jogX / _blocoWidth ))
			_tmp1=$(( ((_jogX+15)) / _blocoWidth ))
		else
			_tmp1=$(( _jogX / _blocoWidth ))
			_tmp2=$(( ((_jogX+15)) / _blocoWidth ))
		fi

		ColisaoBloco $_tmp1 #verifica se houve colisao com o primeiro quadrante
		if [ $? -eq 0 ]; then #se nao houve
			ColisaoBloco $_tmp2 #verifica se houve colisao com o segundo quadrante
		fi
		
		#verifica colisao com as moedas, como a largura do personagem equivale a 3 moedas por isso 3 testes
		ColisaoCoin $(( _jogX / _coinWidth ))
		ColisaoCoin $(( ((_jogX + 8)) / _coinWidth ))
		ColisaoCoin $(( ((_jogX + 15)) / _coinWidth ))

		ColisaoEnemy
		ColisaoMastro

	fi


}

function ColisaoMastro {

	if [ $((_jogX + _jogWidth)) -gt 2880 ]; then

		_screenGame="WIN"
		Play "flagpole"
		_flagY=$_jogY		
		_velocY=0
		_tmp=$(( ((21 - $_jogY) * 330) + 50 ))

		_tmpL=${#_tmp}
		((_tmpL+=2))

		_flagDraw[4]="${_flagDraw[4]:0:2}$_tmp${_flagDraw[4]:$_tmpL}"		

		Score $_tmp
		_jogX=$(( 2883 - _jogWidth))
	fi

}

#funcao colisao inimigo
function ColisaoEnemy {

	#_firstQ=$(( _cameraX / _tamQuad )) #pega o primeiro quadrante
	_ubound=${_enemyX[0]}

	for (( _k=1; _k<_ubound; _k++ )); do #laco para verificar cada inimigo

		#verifica se o path do inimigo esta visivel na camera
		if [ ${_enemyPathIni[$_k]} -lt $((_cameraX + _width)) ] && [ ${_enemyPathFim[$_k]} -gt $_cameraX ] && [ ${_enemySprite[$_k]} -lt 3 ]; then 
			if [ $_jogX -gt $((_enemyX[_k] + _enemyWidth -1)) ]; then #personagem esta do lado direito do inimigo
				_tmp=0 

			elif [ $_jogY -gt $((_enemyY[_k] + _enemyHeight[_k] -1)) ]; then #personagem esta do lado de baixo do inimigo
				_tmp=0

			elif [ $((_jogX + _jogWidth -1)) -lt ${_enemyX[$_k]} ]; then #personagem esta do lado esquerdo do inimigo
				_tmp=0

			elif [ $((_jogY + _jogHeight -1)) -lt ${_enemyY[$_k]} ]; then #personagem esta do lado de cima do inimigo
				_tmp=0

			#A partir daqui houve colisao
			#Próximo if verifica se a colisão foi lateral entao o personagem morre
			elif [ $((_jogY + _jogHeight -1 - _velocY)) -lt ${_enemyY[$_k]} ]; then
				Play "enemy"
				Score 100				
				_jogY=$((_enemyY[_k] - _jogHeight)) 
				_velocY=-3
				_enemySprite[$_k]=2
				_enemyDead[$_k]=1
				return 1 #retorna que houve colisao
			else
				Dead "enemy"
				_velocY=-5
				_jogSprite=0
				if [ $_jogSide = "D" ]; then
					((_jogX=_enemyX[_k] - _jogWidth))
				else
					((_jogX=_enemyX[_k] + _enemyWidth))
				fi
				_jogSide="F"
				return 1 #retorna que houve colisao
			fi

			
		fi
	done

}

#funcao para colisao com moedas
function ColisaoCoin {

	_tmpQ=$1 #recebe o quadrante para teste

	_tmp=${_coinQ[$_tmpQ]} #pega a posicao do indice do vetor das moedas se existir

	if [ $_tmpQ -eq 0 ] || [ -z $_tmp ]; then #verifica se o indíce do quadrante não é zero e se existe moeda no quadrante
		return
	fi

	_coinX=${_coin[$_tmp]} #pega a posicao x da moeda

	if [ $_coinX -gt 0 ]; then #se existir moeda checar colisao

		if [ $_jogX -gt $((_coinX + _coinWidth)) ]; then #personagem esta do lado direito da moeda
			return 0 #retorna que nao houve colisao
		fi

		if [ $((_jogY)) -gt $((_coinY[_tmp] + _coinHeight)) ]; then #personagem esta do lado de baixo da moeda
			return 0 #retorna que nao houve colisao
		fi

		if [ $((_jogX + 15)) -lt $_coinX ]; then #personagem esta do lado esquerdo da moeda
			return 0 #retorna que nao houve colisao
		fi

		if [ $((_jogY+_jogHeight)) -lt ${_coinY[$_tmp]} ]; then #personagem esta do lado de cima da moeda
			return 0 #retorna que nao houve colisao
		fi

		Play "coin" #toca o som da moeda
		_coin[$_tmp]=0 #tira a moeda do vetor
		GetCoin #chama funcao para fazer contagem de ponto da moeda				

		_tmp2=$(( _coinX + _coinWidth )) #pega a posicao do final da moeda

#		for (( _k=9; _k<=13; _k++ )); do #limpa o desenho da moeda no buffer da fase

#			_fasel[$_k]="${_fasel[$_k]:0:$_coinX}${_coinClear}${_fasel[$_k]:$_tmp2}"

#		done

		return 1 #retorna que houve colisao
	fi

}

#funcao para contagem de pontos da moeda
function GetCoin {

	((_coins++)) #incrementa ponto da moeda
	Score 200 #incrementa ponto do score

	if [ $_coins -gt 99 ]; then #verifica se moedas chegou a 100 para converter em vida

		((_coins-=100)) #subtrai 100 moedas do contador
		Play "up" #toca som de ganho de vida
		((_jogLife++)) #incrementa 1 na variavel vida
	fi

}

#funcao para colisao do bloco
function ColisaoBloco {

	_tmpQ=$1 #recebe a posicao do quadrante
	
	_tmp=${_blocoQ[$_tmpQ]} #recebe a posicao do indice do bloco se existir

	if [ $_tmpQ -eq 0 ] || [ -z $_tmp ]; then #verifica se o indíce do quadrante não é zero e se existe bloco no quadrante
		return 0 #retorna que nao houve colisao
	fi

	_blocoX=${_bloco[$_tmp]} #pega a posicao x do bloco

	if [ $_blocoX -gt 0 ]; then #se existir bloco checar colisao

		if [ $_jogX -gt $((_blocoX -1 + _blocoWidth)) ]; then #personagem esta do lado direito do bloco
			return 0 #retorna que nao houve colisao
		fi

		if [ $((_jogY)) -gt $((_blocoY -1 + _blocoHeight)) ]; then #personagem esta do lado de baixo do bloco
			return 0 #retorna que nao houve colisao
		fi

		if [ $((_jogX -1 + _jogWidth)) -lt $_blocoX ]; then #personagem esta do lado esquerdo do bloco
			return 0 #retorna que nao houve colisao
		fi

		if [ $((_jogY -1 + _jogHeight)) -lt $_blocoY ]; then #personagem esta do lado de cima do bloco
			return 0 #retorna que nao houve colisao
		fi

		#A partir daqui houve colisao
		#Próximo if verifica se a colisão foi lateral para não quebrar o bloco
		if [ $((_jogY - _velocY)) -lt $((_blocoY -1 + _blocoHeight)) ]; then

			if [ $_jogSide = "D" ]; then # se não houve colisao posiciona o jogador ao lado do bloco
				_jogX=$((_blocoX - 16))
			else
				_jogX=$((_blocoX + _blocoWidth))
			fi
			_velocX=0
			return 1

		fi

		Play "bloco" #som do bloco quebrando
		Score 50 #incrementa score			
		_bloco[$_tmp]=0 #Limpa o bloco do vetor
		_jogY=$((_blocoY + _blocoHeight)) #posiciona o jogador abaixo do bloco
		_velocY=$((- _velocY)) #incrementa a velocidade de y


		_tmp2=$(( _blocoX + _blocoWidth )) #variavel para definir final do desenho do bloco (limpar)

		for (( _k=_blocoY; _k<_blocoY+_blocoHeight; _k++ )); do #limpa o desenho do bloco do buffer da fase
			_fasel[$_k]="${_fasel[$_k]:0:$_blocoX}${_blocoClear}${_fasel[$_k]:$_tmp2}"
		done

		return 1 #retorna que houve colisao
	fi

}

#Funcao para detectar colisao do personagem com buracos na fase
function ColisaoBuraco {

	for (( _k=1; _k<_buraco[0]; _k++ )); do

		_buracoX=${_buraco[$_k]}

		if [ $((_jogX + (_jogWidth/2))) -gt $((_buracoX+2)) ] && [ $((_jogX + (_jogWidth/2))) -lt $((_buracoX + 2 + _buracoWidth )) ]; then #se houve colisão então mata personagem

			_jogX=$((_buracoX + 2 +(_buracoWidth/2) - (_jogWidth/2) ))
			Dead "buraco"

			return 1 #houve colisao
		fi

	done
	return 0 #nao houve colisao
}

#Função para matar o personagem definindo trilha sonora e tipo de animação do personagem
function Dead {

	#Define que o jogo está na passagem de morte do personagem
	_screenGame="DEAD"

	((_jogLife--)) #Subtrai um vida do personagem
	
	if [ $_jogLife = 0 ]; then #se zerou as vidas do jogador toca audio fim de jogo
		Play "gameover"
	else #se não toca audio de perda de vida
		Play "die"
	fi	

	_jogDead=true #define variavel verdadeira para rotina de animação da morte do personagem

	((_velocY+=_gravidade)) #Atualaiza velocidade de queda do personagem
}

#Função para parar a musica
function Stop {

	kill -9 $1 1 2>/dev/null

}


#Função para tocar os audios
function Play {

	if [ $_sound = "off" ]; then
		return
	fi

	case $1 in #Seleciona qual audio deve ser tocado

		"worldcleared")
			canberra-gtk-play --file="worldcleared.ogg" 1 2>/dev/null&
			;;

		"flagpole")
			if [ $_musicId ]; then
				Stop $_musicId #Mata o processo da musica de fundo
			fi
			canberra-gtk-play --file="flagpole.ogg" 1 2>/dev/null&
			;;

		"timewarning")
			if [ $_musicId ]; then
				Stop $_musicId #Mata o processo da musica de fundo
			fi
			canberra-gtk-play --file="timewarning.ogg" 1 2>/dev/null&
			;;

		"gameover")
			if [ $_musicId ]; then
				Stop $_musicId #Mata o processo da musica de fundo
			fi
			canberra-gtk-play --file="gameover.ogg" 1 2>/dev/null&
			;;

		"die")
			if [ $_musicId ]; then
				Stop $_musicId #Mata o processo da musica de fundo
			fi
			canberra-gtk-play --file="die.ogg" 1 2>/dev/null&
			;;

		"background")
			if [ $_musicId ]; then
				Stop $_musicId #Mata o processo da musica de fundo
			fi

			canberra-gtk-play -l 99 -V 0 --file="world1-1.ogg" 1 2>/dev/null & _musicId="$!"
			#Guarda o id do processo da musica para parar quando for preciso
			;;

		"jump")
			canberra-gtk-play --file="jump.ogg" 1 2>/dev/null&;;

		"bloco")
			canberra-gtk-play --file="brick.ogg" 1 2>/dev/null&;;

		"point")
			canberra-gtk-play --file="coin.ogg" 1 2>/dev/null&;;

		"coin")
			canberra-gtk-play --file="coin.ogg" 1 2>/dev/null&;;

		"up")
			canberra-gtk-play --file="up.ogg" 1 2>/dev/null&;;

		"enemy")
			canberra-gtk-play --file="stomp.ogg" 1 2>/dev/null&;;
	esac

}

function MoveEnemy {

	case $_screenGame in

	"GAME") # se jogo em fase processa movimento do inimigo

		#_firstQ=$(( _cameraX / _tamQuad )) #pega o primeiro quadrante
		_ubound=${_enemyX[0]}

		for (( _k=1; _k<_ubound; _k++ )); do #laco para verificar cada inimigo

			#verifica se o path do inimigo esta visivel na camera
			if [ ${_enemyPathIni[$_k]} -lt $((_cameraX + _width)) ] && [ ${_enemyPathFim[$_k]} -gt $_cameraX ] && [ ${_enemySprite[$_k]} -lt 6 ]; then 

				#((_aniEnemy[_k]++))

				#Animacao do inimigo
				case ${_enemySprite[$_k]} in
				0)
					ChangeSpriteEnemy $_k
					_enemySprite[$_k]=1
					_aniEnemy=1

					;;
				1)	
					ChangeSpriteEnemy $_k
					((_enemySprite[_k]+=_aniEnemy))
					;;
				2)
					if [ ${_enemyDead[$_k]} -eq 1 ]; then
						_enemySprite[$_k]=3
					else
						ChangeSpriteEnemy $_k
						_enemySprite[$_k]=1
						_aniEnemy=-1
					fi
					;;
				3)
					_enemySprite[$_k]=4;;
				4)
					_enemySprite[$_k]=5;;
				5)
					_enemySprite[$_k]=6;;
				esac 

			fi


			_enemyHeight[$_k]="_gompa${_enemySprite[$_k]}[0]"	
			_enemyHeight[$_k]=${!_enemyHeight[$_k]}
			_enemyY[$_k]=$((_piso - _enemyHeight[$_k]))

		done
		
	esac
}

function ChangeSpriteEnemy {

	_k=$1

#	if [ ${_aniEnemy[$_k]} -eq 2 ]; then
		((_enemyX[_k]+=_enemyVelocX[_k])) #Movimenta o inimigo

		if [ $(( _enemyX[_k] + enemyWidth )) -gt $(( _enemyPathFim[_k] )) ] || [ ${_enemyX[$_k]} -lt ${_enemyPathIni[$_k]} ]; then
			(( _enemyVelocX[_k]=-_enemyVelocX[_k] ))
		fi


		_aniEnemy[$_k]=0
#	fi


}

# [ INICIO SCRIPT ] ----------------------------------------------------------------------------------------------------------

# Carrega as configurações salva
. .settings

# Mapa do score no topo da tela
_scoreTitle0="     MARIO                                   WORLD               TIME           "
_scoreTitle1="     000000                 @x00              1-1                 000           "


# Mapa de caracters do jogador mario e das montanhas de fundo

_montDraw[0]=7
_montDraw[1]="              ████████              "
_montDraw[2]="          ████        ████          "
_montDraw[3]="        ██                ██        "
_montDraw[4]="      ██           ██ ░░░░  ██      "
_montDraw[5]="    ██           ██       ░░  ██    "
_montDraw[6]="  ██                        ░░  ██  "
_montDraw[7]="██                            ░░  ██"

# Mapa de caracters do Menu do jogo
 _menu[0]="                                                                                "
 _menu[1]="                                                                                "
 _menu[2]="                                                                                "
 _menu[3]="                                                                                "
 _menu[4]="                                                                                "
 _menu[5]="               @                                                @               "
 _menu[6]="                    ██   ██   ████   █████   ██████   ████                      "
 _menu[7]="                    ███ ███  ██  ██  ██  ██    ██    ██  ██                     "
 _menu[8]="                    ██ █ ██  ██████  █████     ██    ██  ██                     "
 _menu[9]="                    ██   ██  ██  ██  ██  ██    ██    ██  ██                     "
_menu[10]="                    ██   ██  ██  ██  ██  ██  ██████   ████                      "
_menu[11]="                                                                                "
_menu[12]="                     █████   █████    ████    ████                              "
_menu[13]="                     ██  ██  ██  ██  ██  ██  ██                                 "
_menu[14]="                     █████   █████   ██  ██   ████                              "
_menu[15]="                     ██  ██  ██  ██  ██  ██      ██  ██                         "
_menu[16]="                     █████   ██  ██   ████    ████   ██                         "
_menu[17]="               @                                                @               "
_menu[18]="                                           2012 FATEC CARAPICUIBA               "
_menu[19]="                                                                                "
_menu[20]="                                                                                "
_menu[21]="                                                                                "
_menu[22]="                                                                                "
_menu[23]="                    P R E S S   E N T E R   T O   S T A R T                     "
_menu[24]="                                                                                "
_menu[25]="                                                                                "
_menu[26]="                                TOP - 0000000000                                "
_menu[27]="                                                                                "
_menu[28]="                                                                                "
_menu[29]="                                                                                "
_menu[30]="              ████████                                                          "
_menu[31]="          ████        ████                              █     █     █           "
_menu[32]="        ██                ██                           █ █   █ █   █ █          "
_menu[33]="      ██           ██ ░░░░  ██                        █   █ █   █ █   █         "
_menu[34]="    ██           ██       ░░  ██                     █     █     █     █        "
_menu[35]="  ██                        ░░  ██                  █                   █       "
_menu[36]="██                            ░░  ██               █                     █      "
_menu[37]="░░░░██░░░░░░░░██░░░░░░░░██░░░░░░░░██░░░░░░░░██░░░░░░░░██░░░░░░░░██░░░░░░░░██░░░░"
_menu[38]="█░░░░░░░░██░░░░░░░░██░░░░░░░░██░░░░░░░░██░░░░░░░░██░░░░░░░░██░░░░░░░░██░░░░░░░░█"
_menu[39]="░░░░██░░░░░░░░██░░░░░░░░██░░░░░░░░██░░░░░░░░██░░░░░░░░██░░░░░░░░██░░░░░░░░██░░░░"

_flagDraw[0]=7
_flagDraw[1]="████"
_flagDraw[2]="█   ████"
_flagDraw[3]="█       ███"
_flagDraw[4]="█          ███"
_flagDraw[5]="█       ███"
_flagDraw[6]="█   ████"
_flagDraw[7]="████"

_castle[0]=31
 _castle[1]="  @@@"
 _castle[2]=" @@@@@                           ___     ___     ___     __     ___     ___     ___"
 _castle[3]="  @@@                           |░░░|   |░░░|   |░░░|   |░░|   |░░░|   |░░░|   |░░░|"
 _castle[4]="  | |                           |░░░|   |░░░|   |░░░|   |░░|   |░░░|   |░░░|   |░░░|"
 _castle[5]="  | |                           |░░|░░░░|░░░░|░░░░|░░░░|░░░|░░░░|░░░░|░░░░|░░░░|░░░|"
 _castle[6]="  | |                           |░░░░|░░░░|░░░░|░░░░|░░░░|░░░|░░░░|░░░░|░░░░|░░░░|░|"
 _castle[7]="  | |                           |░░|░░░░|██████░░░|░░░░|░░░|░░░░|░░░░██████░░░░|░░░|"
 _castle[8]="  | |                           |░░░░|░░░██████|░░░░|░░░░|░░░|░░░░|░░██████░|░░░░|░|"
 _castle[9]="  | |                           |░░|░░░░|██████░░░|░░░░|░░░|░░░░|░░░░██████░░░░|░░░|"
_castle[10]="  | |                           |░░░░|░░░██████|░░░░|░░░░|░░░|░░░░|░░██████░|░░░░|░|"
_castle[11]="  | |                           |░░|░░░░|██████░░░|░░░░|░░░|░░░░|░░░░██████░░░░|░░░|"
_castle[12]="  | |                 __     ___|░░░░___░██████|░░░░░___░░░░___░░░░░_██████░___░░░░|___     __"
_castle[13]="  | |                |░░|   |░░░|░░░|░░░|███|░░░|░░░|░░░|░░|░░░|░░░|░░░|███|░░░|░░░|░░░|   |░░|"
_castle[14]="  | |                |░░|   |░░░|░░░|░░░|░░░|░░░|░░░|░░░|░░|░░░|░░░|░░░|░░░|░░░|░░░|░░░|   |░░|"
_castle[15]="  | |                |░░░|░░░░|░░░░|░░░░|░░░░|░░░░|░░░░|░░░░|░░░░|░░░░|░░░░|░░░░|░░░░|░░░░|░░░|"
_castle[16]="  | |                |░|░░░░|░░░░|░░░░|░░░░|░░░░|░░░░|░░░░|░░░░|░░░|░░░░|░░░░|░░░░|░░░░|░░░░|░|"
_castle[17]="  | |                |░░░|░░░░|░░░░|░░░░|░░░░|░░░░|░░░████████░░|░░░░|░░░░|░░░░|░░░░░░|░░░░|░░|"
_castle[18]="  | |                |░|░░░░|░░░░|░░░░|░░░░|░░░░|░░░████████████░░░|░░░░|░░░░|░░░░|░░░░|░░░░|░|"
_castle[19]="  | |                |░░░|░░░░|░░░░|░░░░|░░░░|░░░░|██████████████░░░░|░░░░|░░░░|░░░░░░|░░░░|░░|"
_castle[20]="  | |                |░|░░░░|░░░░|░░░░|░░░░|░░░░|░████████████████░|░░░░|░░░░|░░░░|░░░░|░░░░|░|"
_castle[21]="  | |                |░░░|░░░░|░░░░|░░░░|░░░░|░░░██████████████████░░|░░░░|░░░░|░░░░|░░░░|░░░░|"
_castle[22]="  | |                |░|░░░░|░░░░|░░░░|░░░░|░░░░████████████████████░░░░|░░░░|░░░░|░░░░|░░░░|░|"
_castle[23]="  | |                |░░░|░░░░|░░░░|░░░░|░░░░|░░████████████████████░|░░░░|░░░░|░░░░|░░░░|░░░░|"
_castle[24]="  | |                |░|░░░░|░░░░|░░░░|░░░░|░░░░████████████████████░░░░|░░░░|░░░░|░░░░|░░░░|░|"
_castle[25]="  | |                |░░░|░░░░|░░░░|░░░░|░░░░|░░████████████████████░|░░░░|░░░░|░░░░|░░░░|░░░░|"
_castle[26]="  | |                |░|░░░░|░░░░|░░░░|░░░░|░░░░████████████████████░░░░|░░░░|░░░░|░░░░|░░░░|░|"
_castle[27]="  | |                |░░░|░░░░|░░░░|░░░░|░░░░|░░████████████████████░|░░░░|░░░░|░░░░|░░░░|░░░░|"
_castle[28]="  | |                |░|░░░░|░░░░|░░░░|░░░░|░░░░████████████████████░░░░|░░░░|░░░░|░░░░|░░░░|░|"
_castle[29]=" _| |_               |░░░|░░░░|░░░░|░░░░|░░░░|░░████████████████████░|░░░░|░░░░|░░░░|░░░░|░░░░|"
_castle[30]="|░░░░░|              |░|░░░░|░░░░|░░░░|░░░░|░░░░████████████████████░░░░|░░░░|░░░░|░░░░|░░░░|░|"
_castle[31]="|░░░░░|              |░░░|░░░░|░░░░|░░░░|░░░░|░░████████████████████░|░░░░|░░░░|░░░░|░░░░|░░░░|"

_marioD0[0]=16
 _marioD0[1]=""
 _marioD0[2]="   █████"
 _marioD0[3]='  █░░░░M███'
 _marioD0[4]=' █░░░░░░░░░█'
 _marioD0[5]=' ███  █ ███'
 _marioD0[6]='█  ██ █    █'
 _marioD0[7]='█  ██  █   █'
 _marioD0[8]=' ██   █████'
 _marioD0[9]='  ██     █'
_marioD0[10]=' █░░██░░█'
_marioD0[11]='█░░░░██░░█'
_marioD0[12]='█░░░░█████'
_marioD0[13]=' █   ██ ██'
_marioD0[14]=' █  ░░░███'
_marioD0[15]='  █░░░░░█'
_marioD0[16]='   █████'

_marioE0[0]=16
 _marioE0[1]=""
 _marioE0[2]='    █████'
 _marioE0[3]=' ███M░░░░█'
 _marioE0[4]='█░░░░░░░░░█'
 _marioE0[5]=' ███ █  ███'
 _marioE0[6]='█    █ ██  █'
 _marioE0[7]='█   █  ██  █'
 _marioE0[8]=' █████   ██'
 _marioE0[9]='  █     ██'
_marioE0[10]='   █░░██░░█'
_marioE0[11]='  █░░██░░░░█'
_marioE0[12]='  █████░░░░█'
_marioE0[13]='  ██ ██   █'
_marioE0[14]='  ███░░░  █'
_marioE0[15]='   █░░░░░█'
_marioE0[16]='    █████'

_marioD1[0]=16
 _marioD1[1]='     █████'
 _marioD1[2]='    █░░░░M███'
 _marioD1[3]='   █░░░░░░░░░█'
 _marioD1[4]='   ███  █ ███'
 _marioD1[5]='  █  ██ █    █'
 _marioD1[6]='  █  ██  █   █'
 _marioD1[7]='   ██   █████'
 _marioD1[8]='   ███     █'
 _marioD1[9]=' ██░░░██░░███'
_marioD1[10]='█  ░░░░██░░█░█'
_marioD1[11]='█   ░░██████░ █'
_marioD1[12]=' █  ████ ██ █ █'
_marioD1[13]='  █████████░░█'
_marioD1[14]=' █░░██████░░░█'
_marioD1[15]=' █░░░█  █░░░█'
_marioD1[16]='  ███    ███'

_marioE1[0]=16
 _marioE1[1]='     █████'
 _marioE1[2]='  ███M░░░░█'
 _marioE1[3]=' █░░░░░░░░░█'
 _marioE1[4]='  ███ █  ███'
 _marioE1[5]=' █    █ ██  █'
 _marioE1[6]=' █   █  ██  █'
 _marioE1[7]='  █████   ██'
 _marioE1[8]='   █     ███'
 _marioE1[9]='  ███░░██░░░██'
_marioE1[10]=' █░█░░██░░░░  █'
_marioE1[11]='█ ░██████░░   █'
_marioE1[12]='█ █ ██ ████  █'
_marioE1[13]=' █░░█████████'
_marioE1[14]=' █░░░██████░░█'
_marioE1[15]='  █░░░█  █░░░█'
_marioE1[16]='   ███    ███'

_marioF0[0]=16
 _marioF0[1]='    ███████'
 _marioF0[2]='  ██░░░M░░░██'
 _marioF0[3]=' █░░░░███░░░░█'
 _marioF0[4]='  ███████████'
 _marioF0[5]=' █   █   █   █'
 _marioF0[6]='██    ░░░    ██'
 _marioF0[7]=' █ █████████ █'
 _marioF0[8]='█ █   █░█   ██'
 _marioF0[9]='█  ██ █░█ ██  █'
_marioF0[10]=' █ █░█████░░ █ █'
_marioF0[11]='  █░░░░░░░░█████'
_marioF0[12]=' ████░░░░░█░░░█'
_marioF0[13]='█░░░░█░░░█░░░░█'
_marioF0[14]=' █░░░░█████░░░█'
_marioF0[15]='  █░░░█    ███'
_marioF0[16]='   ███'

_marioD2[0]=16
 _marioD2[1]='     █████  ███'
 _marioD2[2]='    █░░░░M██   █'
 _marioD2[3]='   █░░░░░░░░█  █'
 _marioD2[4]='   ███  █ ███░█'
 _marioD2[5]='  █  ██ █    ░█'
 _marioD2[6]='  █  ██  █   ░█'
 _marioD2[7]='   ██   ██████'
 _marioD2[8]='    ██      ░█'
 _marioD2[9]='  █░░░█░░░█░█'
_marioD2[10]=' ███░░░█░░░████'
_marioD2[11]='█   █░░█ ██ █░░█'
_marioD2[12]='█   █░██████░░░█'
_marioD2[13]=' █░█████████░░█'
_marioD2[14]='█░░░████████░░█'
_marioD2[15]='█░░██████   ██'
_marioD2[16]=' ██ ███'

_marioE2[0]=16
 _marioE2[1]=' ███  █████'
 _marioE2[2]='█   ██M░░░░█'
 _marioE2[3]='█  █░░░░░░░░█'
 _marioE2[4]=' █░███ █  ███'
 _marioE2[5]=' █░    █ ██  █'
 _marioE2[6]=' █░   █  ██  █'
 _marioE2[7]='  ██████   ██'
 _marioE2[8]='  █░      ██'
 _marioE2[9]='   █░█░░░█░░░█'
_marioE2[10]=' ████░░░█░░░███'
_marioE2[11]='█░░█ ██ █░░█   █'
_marioE2[12]='█░░░██████░█   █'
_marioE2[13]=' █░░█████████░█'
_marioE2[14]=' █░░████████░░░█'
_marioE2[15]='  ██   ██████░░█'
_marioE2[16]='         ███ ██'



_marioD00=13
 _marioD01="    █████"
 _marioD02='   █░░░░M███'
 _marioD03='  █░░░░░░░░░█'
 _marioD04='  ███  █ ███'
 _marioD05=' █  ██ █    █'
 _marioD06=' █  ██  █   █'
 _marioD07='  ██   █████'
 _marioD08='   ██     █'
 _marioD09='  █   ██ ██'
_marioD010='  █  ░░░███'
_marioD011='   █░░░░░█'
_marioD012='    █████'

_marioE00=13
 _marioE01='     █████'
 _marioE02='  ███M░░░░█'
 _marioE03=' █░░░░░░░░░█'
 _marioE04='  ███ █  ███'
 _marioE05=' █    █ ██  █'
 _marioE06=' █   █  ██  █'
 _marioE07='  █████   ██'
 _marioE08='   █     ██'
 _marioE09='   ██ ██   █'
_marioE010='   ███░░░  █'
_marioE011='    █░░░░░█'
_marioE012='     █████'

_marioD10=13
 _marioD11='     █████'
 _marioD12='    █░░░░M███'
 _marioD13='   █░░░░░░░░░█'
 _marioD14='   ███  █ ███'
 _marioD15='  █  ██ █    █'
 _marioD16='  █  ██  █   █'
 _marioD17='   ██   █████'
 _marioD18='   ███     █'
 _marioD19='  █ ████ ██ █'
_marioD110='  █████████░░█'
_marioD111=' █░░██████░░░█'
_marioD112=' █░░░█  █░░░█'
_marioD113='  ███    ███'

_marioE10=13
 _marioE11='     █████'
 _marioE12='  ███M░░░░█'
 _marioE13=' █░░░░░░░░░█'
 _marioE14='  ███ █  ███'
 _marioE15=' █    █ ██  █'
 _marioE16=' █   █  ██  █'
 _marioE17='  █████   ██'
 _marioE18='   █     ███'
 _marioE19='  █ ██ ████ █'
_marioE110=' █░░█████████'
_marioE111=' █░░░██████░░█'
_marioE112='  █░░░█  █░░░█'
_marioE113='   ███    ███'

_marioD20=13
 _marioD21='     █████  ███'
 _marioD22='    █░░░░M██   █'
 _marioD23='   █░░░░░░░░█  █'
 _marioD24='   ███  █ ███░█'
 _marioD25='  █  ██ █    ░█'
 _marioD26='  █  ██  █   ░█'
 _marioD27='   ██   ██████'
 _marioD28='    ██      ░█'
 _marioD29='   ██████░░░█'
_marioD210='  █████████░░█'
_marioD211=' █░░███████░░█'
_marioD212='█░░██████  ██'
_marioD213=' ██ ███'

_marioE20=13
 _marioE21=' ███  █████'
 _marioE22='█   ██M░░░░█'
 _marioE23='█  █░░░░░░░░█'
 _marioE24=' █░███ █  ███'
 _marioE25=' █░    █ ██  █'
 _marioE26=' █░   █  ██  █'
 _marioE27='  ██████   ██'
 _marioE28='  █░      ██'
 _marioE29='   █░░░██████'
_marioE210='  █░░█████████'
_marioE211='  █░░███████░░█'
_marioE212='   ██   █████░░█'
_marioE213='         ███ ██'

_gompa0[0]=10                                 
 _gompa0[1]="       ████"
 _gompa0[2]="   ██████████"
 _gompa0[3]="  ███ >████< █"
 _gompa0[4]=" ████ █ ██ █ ██"
 _gompa0[5]="█████   ██   ███"
 _gompa0[6]=" ██████████████"
 _gompa0[7]="  █████░░░░███"
 _gompa0[8]="  ███░░░░░░ "
 _gompa0[9]="  ████░░░░██"
_gompa0[10]="   ████░░██"

_gompa1[0]=10
 _gompa1[1]="      ████"
 _gompa1[2]="   ██████████"
 _gompa1[3]="  ██ >████< ██"
 _gompa1[4]=" ███ █ ██ █ ███"
 _gompa1[5]="████   ██   ████"
 _gompa1[6]=" ██████████████"
 _gompa1[7]="  ████░░░░████"
 _gompa1[8]="     ░░░░░░"
 _gompa1[9]="   ██░░░░░░██"
_gompa1[10]="    ██░░░░██"

_gompa2[0]=10
 _gompa2[1]="     ████"
 _gompa2[2]="   ██████████"
 _gompa2[3]="  █ >████< ███"
 _gompa2[4]=" ██ █ ██ █ ████"
 _gompa2[5]="███   ██   █████"
 _gompa2[6]=" ██████████████"
 _gompa2[7]="  ███░░░░████"
 _gompa2[8]="     ░░░░░░███"
 _gompa2[9]="    ██░░░░████"
_gompa2[10]="     ██░░████"

_gompa3[0]=8                                   
 _gompa3[1]="    ████████"
 _gompa3[2]=" ███ >████< ███"
 _gompa3[3]="████ █ ██ █ ████"
 _gompa3[4]="████   ██   ████"
 _gompa3[5]=" █████░░░░█████"
 _gompa3[6]="     ░░░░░░"
 _gompa3[7]="   ███░░░░███"
 _gompa3[8]="    ███░░███"

_gompa3[0]=5                                                                   
 _gompa3[1]="   ████████████"
 _gompa3[2]=" ████ >████< ████"
 _gompa3[3]="█████ █ ██ █ █████"
 _gompa3[4]="   ███░░░░░░███"
 _gompa3[5]="    ███░░░░███"
 
_gompa4[0]=3                                                                   
 _gompa4[1]="   ████████████"
 _gompa4[2]="█████ █ ██ █ █████"
 _gompa4[3]="    ███░░░░███"

_nuvemDraw[0]=13
 _nuvemDraw[1]="               ███████"
 _nuvemDraw[2]="             ██       ██" 
 _nuvemDraw[3]="           ██           ██"
 _nuvemDraw[4]="          █     █   █  ░  █"
 _nuvemDraw[5]="      ████      █   █   ░  ████"
 _nuvemDraw[6]="   ███                  ░      ███"
 _nuvemDraw[7]=" ██                          ░   █"
 _nuvemDraw[8]=" █                          ░    █"
 _nuvemDraw[9]=" ██   ░░░░            ░    ░░ ███"
_nuvemDraw[10]="   ███   ░░░░     ░    ░░░░░  █"
_nuvemDraw[11]="      ████  ░░░░░░  ██      ██"
_nuvemDraw[12]="          ██      ██  ██████"
_nuvemDraw[13]="            ██████"


_coinDraw0[0]=5
_coinDraw0[1]="    @@    "
_coinDraw0[2]="  @@  @@  "
_coinDraw0[3]=" @  @@  @ "
_coinDraw0[4]="  @@  @@  "
_coinDraw0[5]="    @@    "

_coinDrawC[1]=${_cor[4]}
_coinDrawC[2]=${_cor[4]}
_coinDrawC[3]=${_cor[4]}
_coinDrawC[4]=${_cor[4]}
_coinDrawC[5]=${_cor[4]}

_coinDraw1[0]=5
_coinDraw1[1]="    @@    "
_coinDraw1[2]="   @  @   "
_coinDraw1[3]="  @ @@ @  "
_coinDraw1[4]="   @  @   "
_coinDraw1[5]="    @@    "

_coinDraw2[0]=5
_coinDraw2[1]="    @@    "
_coinDraw2[2]="    @@    "
_coinDraw2[3]="    @@    "
_coinDraw2[4]="    @@    "
_coinDraw2[5]="    @@    "

# Cria o mapa de caracters para o piso
_piso1='░░░░██░░░░'
_piso2='█░░░░░░░░█'

_buracoDraw="██                         ██" # Variavel para desenhar o buraco na fase

# Buffer de desenho do Bloco
_blocoDraw[0]="███████████████"
_blocoDraw[1]="█░░░░░░░░░░░░░█"
_blocoClear="               "

#Inicializa as variaveis existentes no programa
#Salva as configurações atuais do terminal
_terminal=$(stty -g)

# -echo Desliga o que eh digitado na tela
# -icanon desliga o modo canonico
# min 0 minimo de caracters a esperar para fazer leitura
#-icrnl converte o caracter new line[enter] para carrier return para ser detectado em _ListenKey
stty -echo -icanon -icrnl min 0 #time 0

# Desliga o cursor piscante na tela
tput civis

# Define constantes para as Teclas de controle seremm detectadas no _ListenKey
KEY_ENTER=$(printf '\x0d')
KEY_BACKSPACE=$(printf '\x08')
KEY_ESC=$(printf '\x1b')
KEY_UP=$(echo -ne '\e[A')
KEY_LEFT=$(echo -ne '\e[D')
KEY_RIGHT=$(echo -ne '\e[C')
KEY_DOWN=$(echo -ne '\e[B')

if [ $TERM = "linux" ]; then
	_cor[0]="\E[00;37;41m" # logo
	_cor[1]="\E[00;37;46m" # Title
	_cor[2]="\E[00;30;46m" # ceu
	_cor[3]="\E[00;31;42m" # piso
	_cor[4]="\E[00;33;46m" # amarelo para coin
	_cor[5]="\E[00;36;46m" # invisible
else
	_cor[0]="\E[01;37;41m" # logo
	_cor[1]="\E[01;37;46m" # Title
	_cor[2]="\E[02;30;46m" # ceu
	_cor[3]="\E[02;31;42m" # piso
	_cor[4]="\E[01;33;46m" # amarelo para coin
	_cor[5]="\E[00;36;46m" # invisible
fi

#definicao minima de Largura e Altura da tela do jogo em linhas por colunas
_heightScreen=40
_widthScreen=80

# Inicializa variaveis de controle de tempo
#_tempoS=$SECONDS #((10#`date +%S`)) Define o tempo inicial com os segundos desde quando o terminal foi aberto
_tempoN=0
_tempo2N=0

#Controla quantos eventos por segundo devem ocorrer
_next=false

# inicializa variavel para posicao da camera no cenario
_cameraX=0

# inicializa variavel para definir a largura da fase em caracters
_sizeFase=0

#Cores possíveis no terminal
# 0 preto
# 1 vermelho
# 2 verde
# 3 amarelo
# 4 azul escuro
# 5 cinza
# 6 azul claro
# 7 branco

_edgeWidth=30
_edgeScreen=`printf "%${_edgeWidth}s"` # Variavel para permitir renderizar desenhos que ficam com parte visivel na camera e parte nao visivel

_width=0
_height=0

TerminalSize

_score=0 #Variavel para guardar o score atual do jogo
_coins=0 #Variavel para as moedas capturadas no jogo
_world="1-1" #Nivel atual do jogo
_timeGame=300 #Define quanto tempo terá a fase
_timeIni=0 #Guarda o tempo em segundos do inicio do jogo
_time=0 #Tempo atual do jogo em segundos

#Carrega a tela do menu no buffer
LoadMenu

_jogAni=0 #Controla a animacao de sprite para dar sensacao mais real do andar
# guarda qual sprite do personagem sera exibido
_jogSprite=0

#qual lado do jogador (d=direito e=esquerdo) será exibido
_jogSide="D"

_jogHeight=16
_jogWidth=16

# Coordenadas iniciais do jogador x,y e velocidade em x e y
_jogX=0
_jogY=0
_velocY=0
_velocX=0

# define se o jogado morreu
_jogDead=false

#Variavel que guarda as vidas do personagem
_jogLife=0

#Define a tela atual do Jogo se esta: no menu, no jogo ou em pausa no jogo
_screenGame="MENU"

# Fisica do Jogo
_gravidade=1

# Coordenada da posicao do piso no cenario para colisao do personagem
_piso=37

# Variaveis de controle de calculo e exibicao de quadros por segundo do jogo (velocidade do jogo)
_quadroRender=0
_quadros=0
_lps=0 #loops por segundo
_fps=0 #frames por segundo

#Variavel para controle de limpeza do buffer do teclado: ver Function ListenKey
_clearBuffer=false


# Verifica se há linhas suficientes para desenha o jogo no terminal
# caso contrário gera um erro, termina o programa e exibe mensagem para o usuario
if [ $_height -lt $_heightScreen ] || [ $_width -lt $_widthScreen ]; then
	_erro="Terminal deve ter no mínimo $_heightScreen linhas x $_widthScreen colunas!\nEncontrado $_height linhas x $_width colunas."
	Sair
fi

ClearScreen

tput cup $(( _initY + 12 )) 0

echo "$_spaceIni    Copyright (C) 2012 Doriedson Alves Galdino de Oliveira                      "
echo "$_spaceIni                       Thiago Andre Silva                                       "
echo "$_spaceIni                       Vitor Augusto Andrioli                                   "
echo "                                                                                "
echo "$_spaceIni    This program is free software: you can redistribute it and/or modify        "
echo "$_spaceIni    it under the terms of the GNU General Public License as published by        "
echo "$_spaceIni    the Free Software Foundation, either version 3 of the License, or           "
echo "$_spaceIni    (at your option) any later version.                                         "
echo "$_spaceIni                                                                                "
echo "$_spaceIni    This program is distributed in the hope that it will be useful,             "
echo "$_spaceIni    but WITHOUT ANY WARRANTY; without even the implied warranty of              "
echo "$_spaceIni    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the               "
echo "$_spaceIni    GNU General Public License for more details.                                "
echo "                                                                                "
echo "$_spaceIni    You should have received a copy of the GNU General Public License           "
echo "$_spaceIni    along with this program.  If not, see <http://www.gnu.org/licenses/>.       "

read -n1

ClearScreen

# guarda o nanosegundo atual do relógio do sistema, aqui foi usado 10# para conversão de base
# pois quando o segundo chega a 08 dá erro com cálculos por que o bash entende que o número
# é octadecimal e como o sistema octadecimal vai até o 7, entao gera um erro, por isso precisamos
# forçar o entendimento para a base decimal com 10#
_tempoN=$((10#`date +%N`))


# [ TIME LINE ] --------------------------------------------------------------------------------------------------------------------

# loop do jogo (Time Line)
while true; do

	FPS #Atualiza a taxa de quadros por segundo
	
	ListenKey #Houve o Teclado

	if [ $_next = true ]; then
		LoadColors #Carrega as cores de fundo

		MoveEnemy #Calcula movimento do inimigo		

		Jogador #Calcula Coordenadas do Jogador

		Render #Renderiza o jogo no terminal
	fi

	_next=false #Controle para quando poderá calcular o próximo quadro do jogo

done

