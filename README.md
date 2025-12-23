# _**Watercolor Shader**_ - Relatório

## Introdução

Neste projeto pretende-se alcançar um _shader_ aplicado por objeto que replique o tipo de pintura de aquarela (_watercolor_), especificamente a técnica _wet-on-wet_ e com um granulado do papel presente.

### O que é a técnica _wet-on-wet_?

Esta técnica trata-se de quando se aplica um pincel molhado de tinta/pigmento num papel também molhado, permitindo criar manchas de cor difusas que se dispersam de forma irregular, e cujas bordas são suaves e misturam-se e fazem _bloom_ ao entrar em contacto com outras cores. Tem um aspeto transparente, com a tinta pouco concentrada num único lugar.

![Wet-on-Wet Example](Images/wet-on-wet-watercolour-technique.jpg "Exemplo da técnica wet-on-wet em papel granulado.")

### Objetivos

- Aplicar as manchas de cor difusas.
- Mistura de cores nas bordas das manchas.
- _Bloom_.
- Aplicar o granulado do papel nos objetos.

### Diagrama inicial

Esta é a estrutura inicialmente feita para o desenvolvimento deste _shader_.

---

## Manchas de cor difusas

## Mistura de cores nas bordas

## _Bloom_

## Granulação do Papel

Comecei por definir as variáveis que necessitava para imitar a granulação presente no papel. Essas são:

- _GrainNormal_ -> Aceita uma textura do tipo _normal_ que dê e indique onde há relevo.
- _GrainNormalIntensity_ -> Gere quanto desse relevo é usado (ou seja, a intensidade na textura) por meio de um _slider_ que vai de 0(não é usado de todo) a 1(é totalmente usado).
- _GrainRoughness_ -> Gere o quão áspero ou liso também por meio de um _slider_ que vai de 0(liso) a 1(áspero).

De seguida, inicializei essas variáveis no _CBuffer_ com o seu respetivo tipo (_float_ para a _GrainNormalIntensity_ e _GrainRoughness_ pois recebem apenas 1 canal, ao contrário do _float4_ usado na _GrainNormal_ devido a esta aceitar 4 canais (_RGBA_)), e o _sampler_ da _GrainNormal_ para receber essa textura e poder ser usada.  

Inicialmente fiz com que o grão fosse visível quando aplicada uma textura e que o _tilling_ e _offset_ dessa textura podesse ser alterada diretamente no material (_grainSample_).  
De seguida foi feito um _dot product_ entre essa _sample_ e a matriz da componente Y(_Luma_) do espaço de cores YIQ, que é o equivalente à luminosidade (_grainLum_). Mas porque não usar diretamente _RGB_? Simplesmente porque usar RGB bruto pode distorcer o efeito por tom (_hue_), enquanto usar _luma_ fornece um contraste consistente.  
Fiz também um _saturate_ para limitar o valor máximo e mínimo possível de se atingir (_clamp_), seguido de um _lerp_ entre 1.0(_half_) e _grainLum_ com um fator _saturate_(_GrainRoughness_(também _half_)) para que o resultado fique entre 0 e 1.  
No entanto, notei que a luz não estava a influenciar os objetos onde o material com o _shader_ estava aplicado.  

![Grain](Images/Grain_no_light_effect.png "Vê-se o grão.")
![Grain no light effect](Images/Grain_no_light_effect2.png "Vê-se o grão mas não há influência da luz.")

## Luz

Para que haja influência da luz simples, é preciso incluir o _package_ _Lighting_ para ser possível chamar a luz principal da cena por meio do método _GetMainLight()_ (presente no ficheiro _RealtimeLights.hlsl_ importado quando se importa o _package_ mencionado anteriormente) no _vertex shader_. São também chamados o método _GetVertexNormalInputs_ para obter as normais em _world space_ em relação aos vértices do objeto, e o _LightingLambert_ para calcular quanta luz cada vértice recebe.  
Inicialmente a cor apenas aparecia onde a sombra estaria, isto devido a estar a adicionar à _color_ um _float4_ com a _lightAmount_ e uma opacidade. Bastou multiplicar em vez de adicionar para obter o resultado correto (cor e sombras nos lados corretos).  

![Cores do lado da sombra](Images/Cores_do_lado_da_sombra.png "Após adição.")
![Cores e sombras do lado certo](Images/Cores_e_sombras_do_lado_certo.png "Após multiplicação.")

Neste momento, a sombra encontra-se muito intensa.  

---

## Bibliotecas e Referências

### Bibliotecas

Powerpoints e vídeos disponibilizados pelo professor.  
Utilização de IA para tirar dúvidas, consoante a necessidade.

### Referências

#### Arte

[Definição da Técnica](https://www.emilywassell.co.uk/watercolour-for-beginners/list-of-techniques/wet-on-wet-watercolour/)  

#### Unity

[Produto Interno](https://docs.unity3d.com/Packages/com.unity.shadergraph@6.9/manual/Dot-Product-Node.html)  
[Lerp](https://docs.unity3d.com/ScriptReference/Mathf.Lerp.html)  
[Saturação(Método saturate)(não encontrei informação na documentação do Unity)](https://en.wikipedia.org/wiki/Saturation_arithmetic)  
[Luz em Shaders](https://docs.unity3d.com/Packages/com.unity.render-pipelines.universal@14.0/manual/use-built-in-shader-methods-lighting.html)

#### Outros

[Espaço de cores YIQ](https://en.wikipedia.org/wiki/YIQ)  
[Conversão RGB para HSV(YIQ)](https://www.youtube.com/watch?v=kiSKb54cogo)  