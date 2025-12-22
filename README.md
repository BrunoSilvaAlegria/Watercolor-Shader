# _**Watercolor Shader**_ - Relatório

## Introdução

Neste projeto pretende-se alcançar um _shader_ que replique o tipo de pintura de aquarela (_watercolor_), especificamente a técnica _wet-on-wet_ e com um granulado do papel presente.

### O que é a técnica _wet-on-wet_?

Esta técnica trata-se de quando se aplica um pincel molhado de tinta/pigmento num papel também molhado, permitindo criar manchas de cor difusas que se dispersam de forma irregular, e cujas bordas misturam-se e fazem _bloom_ ao entrar em contacto com outras cores. Tem um aspeto transparente, com a tinta pouco concentrada num único lugar.

![Wet-on-Wet Example](Images/wet-on-wet-watercolour-technique.jpg "Exemplo da técnica wet-on-wet em papel granulado")

---

## Granulação do Papel

Comecei por definir as variáveis que necessitava para imitar a granulação presente no papel. Essas são:

- _GrainNormal_ -> Aceita uma textura do tipo _normal_ que dê e indique onde há relevo.
- _GrainNormalIntensity_ -> Gere quanto desse relevo é usado (ou seja, a intensidade na textura) por meio de um _slider_ que vai de 0(não é usado de todo) a 1(é totalmente usado).
- _GrainRoughness_ -> Gere o quão áspero ou liso também por meio de um _slider_ que vai de 0(liso) a 1(áspero).

De seguida, inicializei essas variáveis no _CBuffer_ com o seu respetivo tipo (_float_ para a _GrainNormalIntensity_ e _GrainRoughness_ pois recebem apenas 1 canal, ao contrário do _float4_ usado na _GrainNormal_ devido a esta aceitar 4 canais (_RGBA_)), e o _sampler_ da _GrainNormal_ para receber essa textura e poder ser usada.

---

## Bibliotecas e Referências

### Bibliotecas

Powerpoints e vídeos disponibilizados pelo professor.
Utilização de IA para tirar dúvidas, consoante a necessidade.

### Referências

[text](https://www.emilywassell.co.uk/watercolour-for-beginners/list-of-techniques/wet-on-wet-watercolour/) - Technique Definition
[text](https://www.youtube.com/watch?v=kiSKb54cogo) - HSV convertion from RGB