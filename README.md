# _**Watercolor Shader**_ - Relatório

Por Bruno Alegria.  

---

## Introdução

### Ideia inicial

Neste projeto pretende-se alcançar um _shader_ aplicado por objeto que replique o tipo de pintura de aquarela (_watercolor_), especificamente a técnica _wet-on-wet_ e com um granulado do papel presente.  
Esta ideia foi entretanto alterada.

### Ideia modificada

Decidi modificar a ideia inicial para tornar este projeto diferente e mais original. Continua a ser  um _shader_ aplicado por objeto, mas utilizado de forma mais abstrata.  
Assim, pretendo utilizar a humidade característica desta técnica mencionada anteriormente nas sombras, de forma a criar manchas e com arestas concentradas(ou seja, com mais "água").  
Também pretendo ter um _outline_, já que é um elemento comum quando se cria este tipo de _shader_ e chama mais à atenção. Normalmente este tipo de _shader_ é acompanhado de um _toon shader_, _cel shading_ e/ou de _outlines_.  
Para além disso, continuo a querer ter o granulado do papel.  

### O que é a técnica _wet-on-wet_?

Esta técnica trata-se de quando se aplica um pincel molhado de tinta/pigmento num papel também molhado, permitindo criar manchas de cor difusas que se dispersam de forma irregular, e cujas bordas são suaves e misturam-se, fazendo _bleeding_ e _bloom_, ao entrar em contacto com outras cores. Tem um aspeto transparente, com a tinta pouco concentrada num único lugar.

![Wet-on-Wet Example](Images/wet-on-wet-watercolour-technique.jpg "Exemplo da técnica wet-on-wet em papel granulado.")

### Objetivos inicias

- Aplicar as manchas de cor difusas.
- Mistura de cores nas bordas das manchas.
- _Bloom_.
- Aplicar o granulado do papel nos objetos.

### Objetivos atualizados

- Sombras irregulares que escurecem nas bordas.
- _Outline_.
- Aplicar o granulado do papel nos objetos.

### Diagrama inicial

Esta é a estrutura inicialmente feita para o desenvolvimento deste _shader_.  

---

## Primeira tentativa - Ideia inicial

Esta foi a minha primeira tentativa de construir o _shader_ com a ideia inicial, que entretanto foi abandonada e segui para a nova ideia, que começa no tópico "Segunda Tentativa (com foco do projeto mudado) - Ideia modificada".

### Manchas de cor difusas

Para obter "manchas" difusas, é necessário ter:  

- A textura do pigmento.  
- Bordas suaves e irregulares

Para o pigmento ser aplicado, tive de primeiro dar _sample_ da sua textura. Como o pigmento é espalhado e torna-se cada vez mais difuso, fiz com que este varia-se em relação ao espaço(posição, rotação, etc) e não por meio de _UVs_. Também fiz com que o pigmento escurece-se áreas que apanham luz de acordo com a intensidade do mesmo (pigmentos mais fortes podem escurecer áreas iluminadas).  
Inicialmente, o _shader_ conteve _banding_, que por si só faz com as bordas do pigmento estejam extremamente bem definidas e sem qualquer irregularidade, o que é exatamente o oposto do que se pretende. No entanto, posso usar isso como base e acrescentar _noise_ e suavizar este _banding_ de forma a tornar o seu aspeto mais natural, suave e irregular.  

![Sem pigmento](Images/albedo+grain+shadow.png "Só com o albedo e o grão aplicados (Banding = 3).")
![Com pigmento](Images/albedo+pigment+grain+shadow.png "Albedo, pigmento e grão aplicados (Banding = 3).")
![Banding=5](Images/banding_a_5.png "Banding é igual a 5.")

As bordas do _banding_ já estão um pouco mais suaves, mas falta a parte da irregularidade. Para isso, tentei criar um _noise_ por código para não ter de usar outra textura (e para me desafiar) e isso não funcionou como queria, por isso voltei à opção de usar uma textura para o _noise_.  
Foi aqui que me apercebi do que estava a fazer de mal. Estava a usar a luz, especificamente a direção da mesma, para determinar onde havia manchas e as suas bordas, o que não é o que se pretende. Corrigi isso multiplicando a textura do pigmento pela sua intensidade (somada a um valor para que não fica-se demasiado escura).  

### Mistura de cores

Após investigação e falar com IA, cheguei à conclusão que havia dois caminhos possíveis que podia seguir a partir daqui:  

- _Fake Mix_ -> Usando duas texturas de pigmento que onde fazem _overlap_, subtraem-se instantaneamente para formar uma nova cor (porém não faz nem _bleending_ nem _bloom_). É pouco realista e natural.  
- Simulação -> Usa-se também dois pigmentos mas que se espalham de forma natural ao longo do tempo, por onde houver manchas (nas texturas), e que quando se tocam as suas cores substraem-se e fazem _bleeding_ e _bloom_. Requer um _script_ de C# para determinar como a simulação corre. É muito mais realista e natural.  

Testei a primeira opção e não alcancei muito bons resultados.  
Escolhi então a opção de simulação devido ao que a própria mistura de cores é. Um comportamento. Para além de ser mais realista e criar detalhes que considero essenciais para este projeto (_bleeding_ e _bloom_).

### Granulação do Papel

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

---

## Segunda Tentativa - Ideia modificada

### Sombras

### _Outline_

Este _outline_ aceita uma cor e uma grossura, que podem ser modificadas diretamente no material.
Tive um problema com este elemento, que foi o porquê de o _outline_ apenas ser vísivel de certos ângulos.

![Outline total](Images/outline_total.png "Vê-se todo o outline.")
![Outline parcial](Images/Outline_parcial.png "Vê-se apenas parte do outline.")

Resolvi essa questão passando a extrudar com as _world-space normals_ em vez das _view-space normals_ (simplificar, basicamente).   

Passou disto:  
![Código do outline antigo](Images/code_outline_bad.png)

Para isto:  
![Código do outline novo](Images/code_outline_good.png)

Agora vê-se todo o _outline_ independentemente de onde se está a olhar.  

![Vista de cena outline](Images/outline_scene_view.png "Vê-se todo o outline de todos objetos.")

### Granulado do Papel

Mantive a lógica da primeira tentativa mas retirei a _GrainNormalIntensity_ pois não fazia diferença estar lá ou não.  

---

## Bibliotecas e Referências

### Bibliotecas

Powerpoints e vídeos disponibilizados pelo professor.  
Utilização de IA para tirar dúvidas, consoante a necessidade.

### Referências

#### Arte

[Definição da Técnica](https://www.emilywassell.co.uk/watercolour-for-beginners/list-of-techniques/wet-on-wet-watercolour/)  
[Watercolor shader - Devblog#13](https://www.bruteforcegame.com/post/watercolor-shader-devblog-13)  
[Watercolor Shader Experiments (Part 1) by Renne Harris](http://www.reneeharris.co.nz/2024/02/watercolor-shader-experiments-part-1.html)  

#### Unity

[Múltlipas variáveis built-in de shaders](https://docs.unity3d.com/6000.3/Documentation/Manual/SL-UnityShaderVariables.html)    
[TRANSFORM_TEX](https://docs.unity3d.com/Packages/com.unity.render-pipelines.universal@8.2/manual/writing-shaders-urp-unlit-texture.html)  
[Normalize](https://thebookofshaders.com/glossary/?search=normalize)  
[Dot Product](https://docs.unity3d.com/Packages/com.unity.shadergraph@6.9/manual/Dot-Product-Node.html)  
[Lerp](https://docs.unity3d.com/ScriptReference/Mathf.Lerp.html)  
[Saturate](https://learn.microsoft.com/en-us/windows/win32/direct3dhlsl/dx-graphics-hlsl-saturate)  
[Floor](https://learn.microsoft.com/en-us/windows/win32/direct3dhlsl/dx-graphics-hlsl-floor)  
[Max](https://thebookofshaders.com/glossary/?search=max)  
[Smoothstep](https://thebookofshaders.com/glossary/?search=smoothstep)  
[FWidth](https://learn.microsoft.com/en-us/windows/win32/direct3dhlsl/dx-graphics-hlsl-fwidth)
[Exp](https://thebookofshaders.com/glossary/?search=exp)  
[Luz em Shaders](https://docs.unity3d.com/Packages/com.unity.render-pipelines.universal@14.0/manual/use-built-in-shader-methods-lighting.html)  
[Precisão fixa - tipo "fixed"](https://docs.unity3d.com/2022.3/Documentation/Manual/SL-DataTypesAndPrecision.html)  

#### Outros

[Documentação sobre HLSL](https://learn.microsoft.com/en-us/windows/win32/direct3dhlsl/dx-graphics-hlsl-reference)  
[Semântica dos Vertex e Pixel shaders](https://learn.microsoft.com/en-us/windows/win32/direct3dhlsl/dx-graphics-hlsl-semantics)  
[Espaço de cores YIQ](https://en.wikipedia.org/wiki/YIQ)  
[Conversão RGB para HSV(YIQ)](https://www.youtube.com/watch?v=kiSKb54cogo)  
[Síntaxe de Markdown](https://www.markdownguide.org/basic-syntax/)  