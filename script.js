// Configuração global e estado da aplicação
        const API_URL = 'http://127.0.0.1:5000';
        let todosCarros = [];
        let feedEvolucoesCache = {};
        let modoGaragem = "todos";
        let equipeParaReabrirAposProjeto = null;
        let perfilParaReabrirAposProjeto = null;
        let garagemCompletaParaReabrirAposProjeto = null;

        if ('scrollRestoration' in history) {
            history.scrollRestoration = 'manual';
        }

        function resetarScrollPaginaInicial() {
            if (window.location.hash) {
                return;
            }

            window.scrollTo({
                top: 0,
                left: 0,
                behavior: 'auto'
            });

            requestAnimationFrame(() => {
                window.scrollTo({
                    top: 0,
                    left: 0,
                    behavior: 'auto'
                });
            });

            setTimeout(() => {
                window.scrollTo({
                    top: 0,
                    left: 0,
                    behavior: 'auto'
                });
            }, 120);
        }

        window.addEventListener('load', resetarScrollPaginaInicial);

        window.addEventListener('pageshow', function(event) {
            if (event.persisted) {
                resetarScrollPaginaInicial();
            }
        });

        function textoFeedbackSeguro(valor) {
            return String(valor || '')
                .replace(/&/g, '&amp;')
                .replace(/</g, '&lt;')
                .replace(/>/g, '&gt;')
                .replace(/"/g, '&quot;')
                .replace(/'/g, '&#039;');
        }

        function mostrarMensagem(mensagem, tipo = 'sucesso', duracao = 3600) {
            const container = document.getElementById('feedback-container');

            if (!container) {
                alert(mensagem);
                return;
            }

            const tiposPermitidos = ['sucesso', 'erro', 'aviso'];
            const tipoFinal = tiposPermitidos.includes(tipo) ? tipo : 'sucesso';

            const titulos = {
                sucesso: 'Tudo certo',
                erro: 'Algo deu errado',
                aviso: 'Atenção'
            };

            const item = document.createElement('div');
            item.className = `feedback-item feedback-${tipoFinal}`;

            item.innerHTML = `
                <div class="feedback-conteudo">
                    <strong>${titulos[tipoFinal]}</strong>
                    <span>${textoFeedbackSeguro(mensagem)}</span>
                </div>

                <button 
                    type="button" 
                    class="feedback-fechar" 
                    aria-label="Fechar mensagem"
                >
                    ×
                </button>
            `;

            const remover = () => {
                item.classList.add('saindo');

                setTimeout(() => {
                    item.remove();
                }, 220);
            };

            item.querySelector('.feedback-fechar').addEventListener('click', remover);

            container.appendChild(item);

            setTimeout(remover, duracao);
        }

        function confirmarAcao({
            titulo = "Confirmar ação",
            mensagem = "Tem certeza que deseja continuar?",
            textoConfirmar = "Confirmar",
            textoCancelar = "Cancelar"
        } = {}) {
            return new Promise((resolve) => {
                const modalExistente = document.querySelector('.confirmacao-overlay');

                if (modalExistente) {
                    modalExistente.remove();
                }

                const overlay = document.createElement('div');
                overlay.className = 'confirmacao-overlay';

                overlay.innerHTML = `
                    <div class="confirmacao-card">
                        <div class="confirmacao-icone">!</div>

                        <h3>${textoFeedbackSeguro(titulo)}</h3>
                        <p>${textoFeedbackSeguro(mensagem)}</p>

                        <div class="confirmacao-acoes">
                            <button type="button" class="btn-confirmacao-cancelar">
                                ${textoFeedbackSeguro(textoCancelar)}
                            </button>

                            <button type="button" class="btn-confirmacao-confirmar">
                                ${textoFeedbackSeguro(textoConfirmar)}
                            </button>
                        </div>
                    </div>
                `;

                document.body.appendChild(overlay);

                let fechado = false;

                const fechar = (resultado) => {
                    if (fechado) {
                        return;
                    }

                    fechado = true;
                    document.removeEventListener('keydown', fecharComEsc);

                    overlay.classList.add('saindo');

                    setTimeout(() => {
                        overlay.remove();
                        resolve(resultado);
                    }, 180);
                };

                function fecharComEsc(event) {
                    if (event.key === 'Escape') {
                        fechar(false);
                    }
                }

                overlay.querySelector('.btn-confirmacao-cancelar').addEventListener('click', () => {
                    fechar(false);
                });

                overlay.querySelector('.btn-confirmacao-confirmar').addEventListener('click', () => {
                    fechar(true);
                });

                overlay.addEventListener('click', (event) => {
                    if (event.target === overlay) {
                        fechar(false);
                    }
                });

                document.addEventListener('keydown', fecharComEsc);
            });
        }

        function formatarTempoRelativo(dataTexto) {
            if (!dataTexto) {
                return "";
            }

            let data = new Date(dataTexto);

            if (isNaN(data.getTime())) {
                return dataTexto;
            }

            const agora = new Date();

            data = new Date(data.getTime() + (3 * 60 * 60 * 1000));

            let diferencaEmSegundos = Math.floor((agora - data) / 1000);

            if (diferencaEmSegundos < 0) {
                diferencaEmSegundos = 0;
            }

            if (diferencaEmSegundos < 10) {
                return "agora";
            }

            if (diferencaEmSegundos < 60) {
                return `há ${diferencaEmSegundos} segundos`;
            }

            const diferencaEmMinutos = Math.floor(diferencaEmSegundos / 60);

            if (diferencaEmMinutos < 60) {
                return diferencaEmMinutos === 1 ? "há 1 minuto" : `há ${diferencaEmMinutos} minutos`;
            }

            const diferencaEmHoras = Math.floor(diferencaEmMinutos / 60);

            if (diferencaEmHoras < 24) {
                return diferencaEmHoras === 1 ? "há 1 hora" : `há ${diferencaEmHoras} horas`;
            }

            const diferencaEmDias = Math.floor(diferencaEmHoras / 24);

            if (diferencaEmDias < 30) {
                return diferencaEmDias === 1 ? "há 1 dia" : `há ${diferencaEmDias} dias`;
            }

            return data.toLocaleDateString();
        }

        function getUsuarioLogado() {
            const usuario = localStorage.getItem('usuarioLogado');

            if (!usuario) {
                return null;
            }

            return JSON.parse(usuario);
        }

        function usuarioEDono(carro) {
            const usuario = getUsuarioLogado();

            if (!usuario) {
                return false;
            }

            return String(carro.usuario_id) === String(usuario.id);
        }

        function mostrarTodosProjetos() {
            modoGaragem = "todos";

            document.getElementById('aba-todos').classList.add('ativo');
            document.getElementById('aba-meus').classList.remove('ativo');

            carregarGaragem();
        }

        function mostrarMeusProjetos() {
            modoGaragem = "meus";

            document.getElementById('aba-meus').classList.add('ativo');
            document.getElementById('aba-todos').classList.remove('ativo');

            carregarGaragem();
        }

        function atualizarTelaUsuario() {
            const usuario = getUsuarioLogado();

            if (usuario) {
                document.getElementById('auth-container').style.display = "none";
                document.getElementById('usuario-barra').style.display = "block";
                document.getElementById('conteudo-app').style.display = "block";
                const nomeEl = document.getElementById('usuario-nome');
                const avatarEl = document.getElementById('usuario-avatar');

                nomeEl.innerText = usuario.username
                    ? `@${usuario.username}`
                    : usuario.nome;

                if (usuario.avatar_url) {
                    const src = usuario.avatar_url.startsWith('http')
                        ? usuario.avatar_url
                        : `${API_URL}/uploads/${usuario.avatar_url}`;

                    avatarEl.innerHTML = `<img src="${src}">`;
                } else {
                    avatarEl.innerText = usuario.nome.charAt(0).toUpperCase();
                }
                document.getElementById('input-dono').value = usuario.nome;

                carregarGaragem();
            } else {
                document.getElementById('auth-container').style.display = "block";
                document.getElementById('usuario-barra').style.display = "none";
                document.getElementById('conteudo-app').style.display = "none";
            }
        }

        function mostrarFeedbackAuth(mensagem, tipo = 'aviso') {
            const feedback = document.getElementById('auth-feedback');

            if (!feedback) {
                mostrarMensagem(mensagem, tipo);
                return;
            }

            const tiposPermitidos = ['sucesso', 'erro', 'aviso'];
            const tipoFinal = tiposPermitidos.includes(tipo) ? tipo : 'aviso';

            feedback.className = `auth-feedback auth-feedback-${tipoFinal}`;
            feedback.innerText = mensagem;
            feedback.style.display = 'block';
        }

        function limparFeedbackAuth() {
            const feedback = document.getElementById('auth-feedback');

            if (!feedback) {
                return;
            }

            feedback.innerText = '';
            feedback.style.display = 'none';
        }

        function configurarInteracoesAuth() {
            const camposLogin = [
                document.getElementById('login-email'),
                document.getElementById('login-senha')
            ].filter(Boolean);

            const camposCadastro = [
                document.getElementById('cadastro-nome'),
                document.getElementById('cadastro-username'),
                document.getElementById('cadastro-email'),
                document.getElementById('cadastro-senha')
            ].filter(Boolean);

            [...camposLogin, ...camposCadastro].forEach(campo => {
                campo.addEventListener('input', limparFeedbackAuth);
            });

            camposLogin.forEach(campo => {
                campo.addEventListener('keydown', event => {
                    if (event.key !== 'Enter') {
                        return;
                    }

                    event.preventDefault();
                    loginUsuario();
                });
            });

            camposCadastro.forEach(campo => {
                campo.addEventListener('keydown', event => {
                    if (event.key !== 'Enter') {
                        return;
                    }

                    event.preventDefault();
                    cadastrarUsuario();
                });
            });
        }

        function mostrarLogin() {
            document.getElementById('area-login').style.display = "grid";
            document.getElementById('area-cadastro').style.display = "none";

            const modo = document.getElementById('auth-modo');
            const titulo = document.getElementById('auth-titulo');
            const subtitulo = document.getElementById('auth-subtitulo');

            if (modo) modo.innerText = "Login";
            if (titulo) titulo.innerText = "Entrar na garagem";
            if (subtitulo) {
                subtitulo.innerText = "Acesse sua conta para continuar acompanhando seus projetos.";
            }

            limparFeedbackAuth();
        }

        function mostrarCadastro() {
            document.getElementById('area-login').style.display = "none";
            document.getElementById('area-cadastro').style.display = "grid";

            const modo = document.getElementById('auth-modo');
            const titulo = document.getElementById('auth-titulo');
            const subtitulo = document.getElementById('auth-subtitulo');

            if (modo) modo.innerText = "Cadastro";
            if (titulo) titulo.innerText = "Criar sua garagem";
            if (subtitulo) {
                subtitulo.innerText = "Monte seu perfil e comece a registrar seus projetos automotivos.";
            }

            limparFeedbackAuth();
        }

        async function cadastrarUsuario() {
            const nome = document.getElementById('cadastro-nome').value.trim();
            const username = document.getElementById('cadastro-username').value.trim().toLowerCase();
            const email = document.getElementById('cadastro-email').value.trim();
            const senha = document.getElementById('cadastro-senha').value.trim();

            if (!nome || !email || !senha) {
                mostrarFeedbackAuth("Preencha nome, email e senha.", "aviso");
                return;
            }

            try {
                const res = await fetch(`${API_URL}/usuarios/cadastro`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({ nome, username, email, senha })
                });

                const resposta = await res.json();

                if (res.ok) {
                    mostrarLogin();
                    document.getElementById('login-email').value = email;
                    document.getElementById('login-senha').value = "";
                    mostrarFeedbackAuth("Conta criada com sucesso. Agora é só entrar na garagem.", "sucesso");
                } else {
                    mostrarFeedbackAuth("Erro: " + (resposta.erro || "Não foi possível criar a conta."), "erro");
                }

            } catch (error) {
                mostrarFeedbackAuth("Erro de conexão com o servidor.", "erro");
                console.error(error);
            }
        }

        async function loginUsuario() {
            const email = document.getElementById('login-email').value.trim();
            const senha = document.getElementById('login-senha').value.trim();

            if (!email || !senha) {
                mostrarFeedbackAuth("Preencha email e senha.", "aviso");
                return;
            }

            try {
                const res = await fetch(`${API_URL}/usuarios/login`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({ email, senha })
                });

                const resposta = await res.json();

                if (res.ok) {
                    localStorage.setItem('usuarioLogado', JSON.stringify(resposta.usuario));
                    mostrarMensagem("Login realizado com sucesso!", "sucesso");
                    atualizarTelaUsuario();
                } else {
                    mostrarFeedbackAuth("Erro: " + (resposta.erro || "Não foi possível fazer login."), "erro");
                }

            } catch (error) {
                mostrarFeedbackAuth("Erro de conexão com o servidor.", "erro");
                console.error(error);
            }
        }

        function sair() {
            fecharTelaProjeto();

            localStorage.removeItem('usuarioLogado');
            resetarFormulario();
            atualizarTelaUsuario();
        }

        function alternarFormularioProjeto() {
            const container = document.getElementById('container-form');
            const botao = document.querySelector('.btn-toggle-form');

            if (!container || !botao) {
                return;
            }

            const estaAberto = container.style.display === 'block';

            container.style.display = estaAberto ? 'none' : 'block';
            botao.innerText = estaAberto ? '+ Estacionar novo projeto' : 'Fechar formulário';

            if (!estaAberto) {
                container.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
        }

        function fecharFormularioProjeto() {
            const container = document.getElementById('container-form');
            const botao = document.querySelector('.btn-toggle-form');

            if (container) {
                container.style.display = 'none';
            }

            if (botao) {
                botao.innerText = '+ Estacionar novo projeto';
            }
        }

        function mostrarSecaoPrincipal(secao) {
            const secoes = {
                garagem: document.getElementById('secao-garagem'),
                diario: document.getElementById('feed-evolucoes'),
                encontros: document.getElementById('secao-encontros')
            };

            const botoes = {
                garagem: document.getElementById('nav-garagem'),
                diario: document.getElementById('nav-diario'),
                encontros: document.getElementById('nav-encontros')
            };

            Object.values(secoes).forEach(secaoEl => {
                if (secaoEl) {
                    secaoEl.classList.remove('secao-principal-ativa');
                }
            });

            Object.values(botoes).forEach(botao => {
                if (botao) {
                    botao.classList.remove('ativo');
                }
            });

            if (secoes[secao]) {
                secoes[secao].classList.add('secao-principal-ativa');
            }

            if (botoes[secao]) {
                botoes[secao].classList.add('ativo');
            }

            if (secao === 'diario') {
                carregarFeedEvolucoes();
            }
        }

        async function carregarFeedEvolucoes() {
            const container = document.getElementById('feed-evolucoes');
            const lista = document.getElementById('lista-feed-evolucoes');

            if (!container || !lista) {
                return;
            }

            if (modoGaragem !== "todos") {
                container.style.display = 'none';
                lista.innerHTML = '';
                return;
            }

            container.style.display = 'block';
            lista.innerHTML = '<div class="feed-evolucoes-vazio">Carregando atualizações...</div>';

            const params = new URLSearchParams();
            const usuario = getUsuarioLogado();

            if (usuario) {
                params.append('usuario_id', usuario.id);
            }

            try {
                const res = await fetch(`${API_URL}/evolucoes/feed?${params.toString()}`);
                const evolucoes = await res.json();

                if (!Array.isArray(evolucoes) || evolucoes.length === 0) {
                    container.style.display = 'none';
                    lista.innerHTML = '';
                    return;
                }

                feedEvolucoesCache = {};

                lista.innerHTML = evolucoes.map(evolucao => {
                    feedEvolucoesCache[evolucao.id] = evolucao;

                    const descricaoOriginal = String(evolucao.descricao || '').trim();
                    const descricaoCurta = descricaoOriginal.length > 150
                        ? `${descricaoOriginal.slice(0, 150).trim()}...`
                        : descricaoOriginal;

                    const imagem = evolucao.imagem_url
                        ? `${API_URL}/uploads/${evolucao.imagem_url}`
                        : (evolucao.foto_url ? `${API_URL}/uploads/${evolucao.foto_url}` : '');

                    const avatar = evolucao.avatar_usuario
                        ? (evolucao.avatar_usuario.startsWith('http')
                            ? evolucao.avatar_usuario
                            : `${API_URL}/uploads/${evolucao.avatar_usuario}`)
                        : '';

                    const nomeAutor = evolucao.username_usuario
                        ? `@${evolucao.username_usuario}`
                        : (evolucao.nome_usuario || 'Usuário');

                    const inicial = String(evolucao.nome_usuario || evolucao.username_usuario || 'G')
                        .charAt(0)
                        .toUpperCase();

                    return `
                        <article class="feed-evolucao-card" onclick="abrirProjetoPeloFeed(${evolucao.id})">
                            <div class="feed-evolucao-topo">
                                ${avatar
                                    ? `<img src="${avatar}" class="feed-evolucao-avatar" alt="">`
                                    : `<div class="feed-evolucao-avatar-fallback">${textoFeedbackSeguro(inicial)}</div>`
                                }

                                <div>
                                    <strong>${textoFeedbackSeguro(nomeAutor)}</strong>
                                    <span>atualizou ${textoFeedbackSeguro(evolucao.modelo)} (${textoFeedbackSeguro(evolucao.ano)})</span>
                                </div>

                                <time>${formatarTempoRelativo(evolucao.criado_em)}</time>
                            </div>

                            ${imagem
                                ? `<img src="${imagem}" class="feed-evolucao-img" alt="Imagem da evolução">`
                                : `<div class="feed-evolucao-sem-img">Sem imagem</div>`
                            }

                            <div class="feed-evolucao-corpo">
                                <span class="feed-evolucao-tag">Diário de evolução</span>
                                <h3>${textoFeedbackSeguro(evolucao.titulo)}</h3>
                                <p>${textoFeedbackSeguro(descricaoCurta)}</p>

                                <button type="button" class="feed-evolucao-abrir">
                                    Abrir projeto
                                </button>
                            </div>
                        </article>
                    `;
                }).join('');

            } catch (error) {
                console.error(error);
                container.style.display = 'none';
            }
        }


        function abrirProjetoPeloFeed(evolucaoId) {
            const evolucao = feedEvolucoesCache[evolucaoId];

            if (!evolucao) {
                mostrarMensagem("Não foi possível abrir este projeto.", "erro");
                return;
            }

            const carro = {
                id: evolucao.carro_id,
                usuario_id: evolucao.carro_usuario_id,
                nome_dono: evolucao.nome_dono,
                modelo: evolucao.modelo,
                ano: evolucao.ano,
                cor: evolucao.cor,
                placa: evolucao.placa,
                tipo_suspensao: evolucao.tipo_suspensao,
                aro_roda: evolucao.aro_roda,
                foto_url: evolucao.foto_url,
                historia: evolucao.historia,
                motor: evolucao.motor,
                cambio: evolucao.cambio,
                combustivel: evolucao.combustivel,
                potencia_estimada: evolucao.potencia_estimada,
                preparacao: evolucao.preparacao,
                status_projeto: evolucao.status_projeto,
                total_curtidas: evolucao.total_curtidas || 0,
                total_comentarios: evolucao.total_comentarios || 0,
                curtido_pelo_usuario: evolucao.curtido_pelo_usuario
            };

            abrirTelaProjeto(carro);
        }

        async function carregarGaragem() {
            const mod = document.getElementById('filtro-modelo').value;
            const sus = document.getElementById('filtro-suspensao').value;
            const aro = document.getElementById('filtro-aro').value;

            const params = new URLSearchParams();

            if (mod) params.append('modelo', mod);
            if (sus) params.append('suspensao', sus);
            if (aro) params.append('aro', aro);

            const usuario = getUsuarioLogado();

            if (usuario) {
                params.append('usuario_id', usuario.id);
            }

            if (modoGaragem === "meus") {
                params.append('apenas_meus', '1');
            }

            try {
                const res = await fetch(`${API_URL}/carros?${params.toString()}`);
                todosCarros = await res.json();

                const galeria = document.getElementById('lista-carros');
                galeria.innerHTML = '';
                galeria.classList.remove('um-card');

                if (!Array.isArray(todosCarros) || todosCarros.length === 0) {
                    galeria.innerHTML = `
                        <div style="text-align:center; color:#666; padding: 30px;">
                            ${modoGaragem === "meus" ? "Você ainda não cadastrou nenhum projeto." : "Nenhum projeto encontrado na garagem."}
                        </div>
                    `;
                    return;
                }

                let carrosParaExibir = todosCarros;

                if (modoGaragem === "meus" && usuario) {
                    carrosParaExibir = todosCarros.filter(carro => String(carro.usuario_id) === String(usuario.id));
                }

                if (carrosParaExibir.length === 0) {
                    galeria.innerHTML = `
                        <div style="text-align:center; color:#666; padding: 30px;">
                            Você ainda não cadastrou nenhum projeto.
                        </div>
                    `;
                    return;
                }

                galeria.classList.toggle('um-card', carrosParaExibir.length === 1);

                carrosParaExibir.forEach(carro => {
                    const img = carro.foto_url ? `${API_URL}/uploads/${carro.foto_url}` : '';
                    const card = document.createElement('div');
                    const dono = usuarioEDono(carro);
                    const totalCurtidas = carro.total_curtidas || 0;
                    const curtido = estaCurtido(carro.curtido_pelo_usuario);

                    card.className = 'carro-card';

                    card.innerHTML = `
                        ${img ? `<img src="${img}" class="foto-carro">` : '<div class="foto-carro" style="display:flex;align-items:center;justify-content:center;color:#333">SEM FOTO</div>'}

                        <div class="card-info">
                            <div class="titulo-card">
                                <h2 style="margin:0">${carro.modelo} (${carro.ano})</h2>
                                ${dono ? '<span class="dono-badge">Seu projeto</span>' : ''}
                            </div>

                            <p class="specs">
                                Proprietário:
                                ${carro.usuario_id
                                    ? `<span class="dono-link" data-id="${carro.usuario_id}">
                                        ${carro.nome_dono}
                                    </span>`
                                    : '---'}
                            </p>

                            <p class="specs">Cor: ${carro.cor}</p>
                            <p class="specs">Câmbio: ${carro.cambio || '---'}</p>

                            <p class="specs">
                                <span style="display:block; margin-top:12px; color:#666; font-size:0.75em; font-weight:bold;">
                                    FICHA TÉCNICA:
                                </span>

                                <span class="destaque">
                                    ARO ${carro.aro_roda} | SUSPENSÃO ${carro.tipo_suspensao}
                                </span>
                            </p>

                            <div class="historia-projeto ${carro.historia ? '' : 'historia-projeto-vazia'}">
                                <strong>História do projeto</strong>
                                ${carro.historia || 'Ainda não adicionada.'}
                            </div>

                            <div class="acoes-principais">
                                <div class="barra-social">
                                    <span class="like-btn ${curtido ? 'curtido' : ''}">
                                        👍 <span>${totalCurtidas}</span>
                                    </span>

                                    <span class="comment-btn">
                                        💬 ${carro.total_comentarios || 0}
                                    </span>
                                </div>

                                <button type="button" class="btn-ver">Ver projeto</button>
                            </div>

                            ${dono ? `
                                <div class="acoes-dono">
                                    <button type="button" class="btn-editar">Editar</button>
                                    <button type="button" class="btn-excluir">Remover</button>
                                </div>
                            ` : ''}
                        </div>
                    `;

                    const donoLink = card.querySelector('.dono-link');

                    if (donoLink) {
                        donoLink.onclick = () => abrirPerfil(donoLink.dataset.id);
                    }

                    card.querySelector('.btn-ver').onclick = () => abrirTelaProjeto(carro);

                    const likeBtn = card.querySelector('.like-btn');

                    likeBtn.onclick = () => {
                        alternarCurtida(carro.id);

                        likeBtn.classList.add('animando');
                        criarParticulas(likeBtn);

                        if (navigator.vibrate) {
                            navigator.vibrate(10);
                        }

                        setTimeout(() => {
                            likeBtn.classList.remove('animando');
                        }, 300);
                    };

                    card.querySelector('.comment-btn').onclick = () => abrirComentariosProjeto(carro);

                    if (dono) {
                        card.querySelector('.btn-editar').onclick = () => prepararEdicao(carro);
                        card.querySelector('.btn-excluir').onclick = () => solicitarExclusao(carro.id);
                    }

                    galeria.appendChild(card);
                });

            } catch (error) {
                mostrarMensagem("Erro ao carregar a garagem. Verifique se o Flask está rodando.", "erro");
                console.error(error);
            }
        }

        async function alternarCurtida(carroId) {
            const usuario = getUsuarioLogado();

            if (!usuario) {
                mostrarMensagem("Faça login para curtir um projeto.", "aviso");
                return;
            }

            try {
                const res = await fetch(`${API_URL}/carros/${carroId}/curtir`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({ usuario_id: usuario.id })
                });

                let resposta = {};

                try {
                    resposta = await res.json();
                } catch {
                    resposta = {};
                }

                if (res.ok) {
                    carregarGaragem();
                } else {
                    mostrarMensagem("Erro: " + (resposta.erro || "Não foi possível atualizar a curtida."), "erro");
                }

            } catch (error) {
                mostrarMensagem("Erro de conexão com o servidor.", "erro");
                console.error(error);
            }
        }

        function criarItemFicha(rotulo, valor) {
            const valorLimpo = String(valor || '').trim();

            return `
                <div class="modal-ficha-item">
                    <span>${textoFeedbackSeguro(rotulo)}</span>
                    <strong>${textoFeedbackSeguro(valorLimpo || '---')}</strong>
                </div>
            `;
        }

        function criarItemFichaOpcional(rotulo, valor) {
            const valorLimpo = String(valor || '').trim();

            if (!valorLimpo) {
                return '';
            }

            return criarItemFicha(rotulo, valorLimpo);
        }

        function criarGrupoFichaTecnica(titulo, itens) {
            const itensValidos = itens.filter(Boolean).join('');

            if (!itensValidos) {
                return '';
            }

            return `
                <section class="modal-ficha-grupo">
                    <h3>${textoFeedbackSeguro(titulo)}</h3>

                    <div class="modal-ficha-lista">
                        ${itensValidos}
                    </div>
                </section>
            `;
        }

        function criarHtmlFichaProjeto(carro) {
            return `
                <div class="modal-ficha">
                    ${criarGrupoFichaTecnica('Identificação', [
                        `
                            <div class="modal-ficha-item">
                                <span>Proprietário</span>
                                ${carro.usuario_id
                                    ? `<strong class="dono-link" onclick="abrirPerfil(${carro.usuario_id})">
                                        ${textoFeedbackSeguro(carro.nome_dono || '---')}
                                    </strong>`
                                    : `<strong>${textoFeedbackSeguro(carro.nome_dono || '---')}</strong>`
                                }
                            </div>
                        `,
                        criarItemFicha('Ano', carro.ano),
                        criarItemFicha('Cor', carro.cor),
                        criarItemFichaOpcional('Placa', carro.placa)
                    ])}

                    ${criarGrupoFichaTecnica('Setup', [
                        criarItemFichaOpcional('Motor', carro.motor),
                        criarItemFichaOpcional('Câmbio', carro.cambio),
                        criarItemFichaOpcional('Combustível', carro.combustivel)
                    ])}

                    ${criarGrupoFichaTecnica('Projeto', [
                        criarItemFicha('Aro', carro.aro_roda),
                        criarItemFicha('Suspensão', carro.tipo_suspensao),
                        criarItemFichaOpcional(
                            'Potência estimada',
                            carro.potencia_estimada ? `${carro.potencia_estimada} cv` : ''
                        ),
                        criarItemFichaOpcional('Preparação', carro.preparacao),
                        criarItemFichaOpcional('Status do projeto', carro.status_projeto)
                    ])}
                </div>
            `;
        }

        function criarTextoToggleComentarios(aberto, total) {
            const totalNormalizado = Number(total) || 0;

            if (aberto) {
                return 'Ocultar comentários';
            }

            if (totalNormalizado === 0) {
                return 'Ver comentários';
            }

            if (totalNormalizado === 1) {
                return 'Ver 1 comentário';
            }

            return `Ver ${totalNormalizado} comentários`;
        }

        function atualizarBotaoComentarios(total) {
            const botao = document.getElementById('btn-toggle-comentarios');
            const container = document.getElementById('comentarios-container');

            if (!botao || !container) {
                return;
            }

            const aberto = !container.classList.contains('comentarios-recolhidos');

            botao.dataset.totalComentarios = total;
            botao.innerText = criarTextoToggleComentarios(aberto, total);
        }

        function alternarComentariosProjeto(botao) {
            const container = document.getElementById('comentarios-container');

            if (!container || !botao) {
                return;
            }

            const abrir = container.classList.contains('comentarios-recolhidos');

            container.classList.toggle('comentarios-recolhidos', !abrir);
            container.classList.toggle('comentarios-abertos', abrir);

            const total = botao.dataset.totalComentarios || 0;
            botao.innerText = criarTextoToggleComentarios(abrir, total);
        }

        function alternarAbaProjeto(aba) {
            const tela = document.getElementById('tela-projeto');

            if (!tela) {
                return;
            }

            tela.querySelectorAll('.pagina-projeto-tab').forEach(botao => {
                const ativo = botao.dataset.aba === aba;

                botao.classList.toggle('ativo', ativo);
                botao.setAttribute('aria-selected', ativo ? 'true' : 'false');
            });

            tela.querySelectorAll('.pagina-projeto-painel').forEach(painel => {
                painel.classList.toggle('ativo', painel.dataset.painel === aba);
            });
        }

        function criarBlocoComentariosProjeto(carro, aberto = false) {
            const totalCurtidas = carro.total_curtidas || 0;
            const curtido = estaCurtido(carro.curtido_pelo_usuario);
            const totalComentarios = carro.total_comentarios || 0;
            const classeEstado = aberto ? 'comentarios-abertos' : 'comentarios-recolhidos';

            return `
                <div class="comentarios-container ${classeEstado}" id="comentarios-container">
                    <div class="comentarios-header comentarios-header-recolhido">
                        <div>
                            <h3>Comentários</h3>
                            <span class="comentarios-subtitulo">
                                Interações da comunidade sobre este projeto
                            </span>
                        </div>

                        <span class="comentarios-like ${curtido ? 'curtido' : ''}" onclick="curtirPeloModal(${carro.id})">
                            👍 ${totalCurtidas} ${totalCurtidas === 1 ? 'curtida' : 'curtidas'}
                        </span>
                    </div>

                    <button
                        type="button"
                        id="btn-toggle-comentarios"
                        class="btn-toggle-comentarios"
                        data-total-comentarios="${totalComentarios}"
                        onclick="alternarComentariosProjeto(this)"
                    >
                        ${criarTextoToggleComentarios(aberto, totalComentarios)}
                    </button>

                    <div class="comentarios-corpo" id="comentarios-corpo">
                        <div id="lista-comentarios"></div>

                        <textarea id="input-comentario" placeholder="Escreva um comentário..."></textarea>
                        <button type="button" class="btn-comentar" onclick="enviarComentario(${carro.id})">
                            Comentar
                        </button>
                    </div>
                </div>
            `;
        }

        function abrirModalProjeto(carro, scrollManter = null) {
            const modal = document.getElementById('modal-projeto');
            const modalContent = document.getElementById('modal-content');
            const modalJaAberto = modal.style.display === "block";

            if (modalJaAberto && modalContent) {
                modalContent.classList.add("trocando-conteudo");
            }

            modal.style.display = "block";
            document.body.style.overflow = "hidden";

            const img = carro.foto_url ? `${API_URL}/uploads/${carro.foto_url}` : '';
            const dono = usuarioEDono(carro);

            modalContent.innerHTML = `
                <button type="button" class="modal-fechar" onclick="fecharModalProjeto()">X</button>

                ${img
                    ? `<img src="${img}" class="modal-img">`
                    : '<div class="modal-sem-foto">Sem foto</div>'
                }

                <div class="modal-info">
                    <h2>${carro.modelo} (${carro.ano})</h2>

                    ${criarHtmlFichaProjeto(carro)}

                    ${carro.historia ? `
                        <div class="historia-projeto">
                            <strong>História do projeto</strong>
                            ${carro.historia}
                        </div>
                    ` : ''}

                    <div class="evolucao-container">
                        <div class="evolucao-header">
                            <div>
                                <h3>Diário de evolução</h3>
                                <span>Últimas atualizações, mudanças e fases do projeto</span>
                            </div>
                        </div>

                        ${dono ? `
                            <form class="evolucao-form" onsubmit="enviarEvolucao(event, ${carro.id})">
                                <input
                                    type="text"
                                    id="input-evolucao-titulo"
                                    placeholder="Título da atualização"
                                    maxlength="120"
                                >

                                <textarea
                                    id="input-evolucao-descricao"
                                    placeholder="Conte o que mudou no projeto..."
                                ></textarea>

                                <label class="upload-container evolucao-upload-container">
                                    <span class="upload-btn">Escolher imagem</span>
                                    <span class="upload-nome" id="evolucao-imagem-nome">Nenhum arquivo</span>

                                    <input
                                        type="file"
                                        id="input-evolucao-imagem"
                                        accept="image/png, image/jpeg, image/webp"
                                    >
                                </label>

                                <button type="submit" class="btn-evolucao">
                                    Registrar evolução
                                </button>
                            </form>
                        ` : ''}

                        <div id="lista-evolucoes" class="evolucao-lista">
                            <div class="evolucao-vazio">Carregando evolução do projeto...</div>
                        </div>
                    </div>

                    ${criarBlocoComentariosProjeto(carro)}

                </div>
            `;

            requestAnimationFrame(() => {
                if (modalContent) {
                    modalContent.classList.remove("trocando-conteudo");
                    modalContent.style.visibility = "visible";
                }

                modal.scrollTop = 0;
                modalContent.scrollTop = 0;
            });

            setTimeout(() => {
                carregarEvolucoes(carro.id);
                carregarComentarios(carro.id);
            }, 100);
        }

        function abrirTelaProjeto(carro) {
            const tela = document.getElementById('tela-projeto');
            const conteudoApp = document.getElementById('conteudo-app');

            if (!tela) {
                abrirModalProjeto(carro);
                return;
            }

            const img = carro.foto_url ? `${API_URL}/uploads/${carro.foto_url}` : '';
            const dono = usuarioEDono(carro);
            const historia = String(carro.historia || '').trim();

            tela.innerHTML = `
                <div class="pagina-projeto">
                    <div class="pagina-projeto-topbar">
                        <button type="button" class="btn-voltar-projeto" onclick="fecharTelaProjeto()">
                            ← Voltar para garagem
                        </button>

                        ${dono ? '<span class="pagina-projeto-badge">Seu projeto</span>' : ''}
                    </div>

                    <section class="pagina-projeto-hero">
                        ${img
                            ? `<img src="${img}" class="pagina-projeto-img">`
                            : '<div class="pagina-projeto-sem-foto">Sem foto</div>'
                        }

                        <div class="pagina-projeto-hero-info">
                            <span class="pagina-projeto-kicker">Projeto automotivo</span>
                            <h2>${textoFeedbackSeguro(carro.modelo)} (${textoFeedbackSeguro(carro.ano)})</h2>
                        </div>
                    </section>

                    <div class="pagina-projeto-conteudo">
                        <nav class="pagina-projeto-tabs" aria-label="Navegação do projeto">
                            <button
                                type="button"
                                class="pagina-projeto-tab ativo"
                                data-aba="visao-geral"
                                aria-selected="true"
                                onclick="alternarAbaProjeto('visao-geral')"
                            >
                                Visão geral
                            </button>

                            <button
                                type="button"
                                class="pagina-projeto-tab"
                                data-aba="galeria"
                                aria-selected="false"
                                onclick="alternarAbaProjeto('galeria')"
                            >
                                Galeria
                            </button>

                            <button
                                type="button"
                                class="pagina-projeto-tab"
                                data-aba="diario"
                                aria-selected="false"
                                onclick="alternarAbaProjeto('diario')"
                            >
                                Diário
                            </button>

                            <button
                                type="button"
                                class="pagina-projeto-tab"
                                data-aba="comentarios"
                                aria-selected="false"
                                onclick="alternarAbaProjeto('comentarios')"
                            >
                                Comentários
                            </button>
                        </nav>

                        <section class="pagina-projeto-painel ativo" data-painel="visao-geral">
                            ${criarHtmlFichaProjeto(carro)}

                            <section class="pagina-projeto-bloco">
                                <h3>História do projeto</h3>
                                <p>${historia ? textoFeedbackSeguro(historia) : 'Ainda não adicionada.'}</p>
                            </section>
                        </section>

                        <section class="pagina-projeto-painel" data-painel="galeria">
                            <section class="pagina-projeto-bloco galeria-projeto-bloco">
                                <div class="galeria-projeto-header">
                                    <div>
                                        <h3>Galeria do projeto</h3>
                                        <span>Fotos extras, detalhes e registros visuais da garagem</span>
                                    </div>
                                </div>

                                ${dono ? `
                                    <form class="galeria-projeto-form" onsubmit="enviarFotoGaleria(event, ${carro.id})">
                                        <label class="upload-container">
                                            <span class="upload-btn">Escolher foto</span>
                                            <span class="upload-nome" id="galeria-foto-nome">Nenhum arquivo</span>

                                            <input
                                                type="file"
                                                id="galeria-foto-input"
                                                accept="image/png, image/jpeg, image/webp"
                                            >
                                        </label>

                                        <input
                                            type="text"
                                            id="galeria-legenda-input"
                                            placeholder="Legenda opcional"
                                            maxlength="120"
                                        >

                                        <button type="submit" class="btn-galeria-projeto">
                                            Adicionar à galeria
                                        </button>
                                    </form>
                                ` : ''}

                                <div id="galeria-projeto-lista" class="galeria-projeto-lista">
                                    <div class="galeria-projeto-vazio">Carregando galeria...</div>
                                </div>
                            </section>
                        </section>

                        <section class="pagina-projeto-painel" data-painel="diario">
                            <section class="pagina-projeto-bloco">
                                <div class="evolucao-header">
                                    <div>
                                        <h3>Diário de evolução</h3>
                                        <span>Últimas atualizações, mudanças e fases do projeto</span>
                                    </div>
                                </div>

                                ${dono ? `
                                    <form class="evolucao-form" onsubmit="enviarEvolucao(event, ${carro.id}, 'lista-evolucoes-tela')">
                                        <input
                                            type="text"
                                            id="input-evolucao-titulo"
                                            placeholder="Título da atualização"
                                            maxlength="120"
                                        >

                                        <textarea
                                            id="input-evolucao-descricao"
                                            placeholder="Conte o que mudou no projeto..."
                                        ></textarea>

                                        <label class="upload-container evolucao-upload-container">
                                            <span class="upload-btn">Escolher imagem</span>
                                            <span class="upload-nome" id="evolucao-imagem-nome">Nenhum arquivo</span>

                                            <input
                                                type="file"
                                                id="input-evolucao-imagem"
                                                accept="image/png, image/jpeg, image/webp"
                                            >
                                        </label>

                                        <button type="submit" class="btn-evolucao">
                                            Registrar evolução
                                        </button>
                                    </form>
                                ` : ''}

                                <div id="lista-evolucoes-tela" class="evolucao-lista">
                                    <div class="evolucao-vazio">Carregando evolução do projeto...</div>
                                </div>
                            </section>
                        </section>

                        <section class="pagina-projeto-painel" data-painel="comentarios">
                            ${criarBlocoComentariosProjeto(carro, true)}
                        </section>
                    </div>
                </div>
            `;

            if (conteudoApp) {
                conteudoApp.style.display = 'none';
            }

            tela.style.display = 'block';
            document.body.classList.add('tela-projeto-aberta');

            window.scrollTo({
                top: 0,
                left: 0,
                behavior: 'auto'
            });

            setTimeout(() => {
                carregarGaleriaProjeto(carro.id, dono);
                carregarEvolucoes(carro.id, 'lista-evolucoes-tela');
                carregarComentarios(carro.id);
            }, 100);
        }

        function fecharTelaProjeto() {
            const tela = document.getElementById('tela-projeto');
            const conteudoApp = document.getElementById('conteudo-app');

            if (tela) {
                tela.style.display = 'none';
                tela.innerHTML = '';
            }

            if (conteudoApp) {
                conteudoApp.style.display = 'block';
            }

            document.body.classList.remove('tela-projeto-aberta');

            window.scrollTo({
                top: 0,
                left: 0,
                behavior: 'auto'
            });
        }

        async function carregarGaleriaProjeto(carroId, dono = false) {
            const lista = document.getElementById('galeria-projeto-lista');

            if (!lista) {
                return;
            }

            try {
                const res = await fetch(`${API_URL}/carros/${carroId}/fotos`);
                const fotos = await res.json();

                if (!res.ok) {
                    console.error("Erro ao carregar galeria:", fotos);
                    lista.innerHTML = '<div class="galeria-projeto-vazio">Não foi possível carregar a galeria.</div>';
                    return;
                }

                if (!Array.isArray(fotos) || fotos.length === 0) {
                    lista.innerHTML = dono
                        ? '<div class="galeria-projeto-vazio">Sua galeria ainda está vazia. Adicione fotos extras do projeto.</div>'
                        : '<div class="galeria-projeto-vazio">Este projeto ainda não tem fotos na galeria.</div>';

                    return;
                }

                lista.innerHTML = fotos.map(foto => {
                    const src = foto.imagem_url ? `${API_URL}/uploads/${foto.imagem_url}` : '';
                    const legenda = String(foto.legenda || '').trim();

                    return `
                        <article class="galeria-projeto-card">
                            ${src
                                ? `<img src="${src}" alt="Foto da galeria do projeto">`
                                : '<div class="galeria-projeto-sem-foto">Sem foto</div>'
                            }

                            <div class="galeria-projeto-info">
                                <strong>${legenda ? textoFeedbackSeguro(legenda) : 'Registro do projeto'}</strong>
                                <span>${formatarTempoRelativo(foto.criado_em)}</span>

                                ${dono ? `
                                    <button
                                        type="button"
                                        class="btn-remover-foto-galeria"
                                        onclick="removerFotoGaleria(${carroId}, ${foto.id})"
                                    >
                                        Remover foto
                                    </button>
                                ` : ''}
                            </div>
                        </article>
                    `;
                }).join('');

            } catch (error) {
                lista.innerHTML = '<div class="galeria-projeto-vazio">Erro ao carregar a galeria.</div>';
                console.error("Falha inesperada ao carregar galeria:", error);
            }
        }


        async function enviarFotoGaleria(event, carroId) {
            event.preventDefault();

            const usuario = getUsuarioLogado();

            if (!usuario) {
                mostrarMensagem("Faça login para adicionar fotos à galeria.", "aviso");
                return;
            }

            const inputFoto = document.getElementById('galeria-foto-input');
            const inputLegenda = document.getElementById('galeria-legenda-input');
            const botao = event.target.querySelector('button[type="submit"]');

            const foto = inputFoto && inputFoto.files.length > 0
                ? inputFoto.files[0]
                : null;

            const legenda = inputLegenda ? inputLegenda.value.trim() : '';

            if (!foto) {
                mostrarMensagem("Escolha uma foto para adicionar à galeria.", "aviso");
                return;
            }

            const tamanhoMaximoImagem = 5 * 1024 * 1024;
            const formatosPermitidos = ['image/png', 'image/jpeg', 'image/webp'];
            const extensoesPermitidas = ['png', 'jpg', 'jpeg', 'webp'];
            const extensao = foto.name.split('.').pop().toLowerCase();

            if (
                !formatosPermitidos.includes(foto.type) ||
                !extensoesPermitidas.includes(extensao)
            ) {
                mostrarMensagem("Formato de imagem inválido. Use PNG, JPG, JPEG ou WEBP.", "aviso");
                return;
            }

            if (foto.size > tamanhoMaximoImagem) {
                mostrarMensagem("Imagem muito pesada. Envie uma imagem com no máximo 5 MB.", "aviso");
                return;
            }

            const formData = new FormData();

            formData.append('usuario_id', usuario.id);
            formData.append('foto', foto);
            formData.append('legenda', legenda);

            try {
                if (botao) {
                    botao.disabled = true;
                    botao.innerText = "Adicionando...";
                }

                const res = await fetch(`${API_URL}/carros/${carroId}/fotos`, {
                    method: 'POST',
                    body: formData
                });

                const resposta = await res.json();

                if (res.ok) {
                    mostrarMensagem(resposta.mensagem || "Foto adicionada à galeria!", "sucesso");

                    event.target.reset();

                    const nomeArquivo = document.getElementById('galeria-foto-nome');

                    if (nomeArquivo) {
                        nomeArquivo.textContent = "Nenhum arquivo";
                    }

                    carregarGaleriaProjeto(carroId, true);
                    return;
                }

                mostrarMensagem("Erro: " + (resposta.erro || "Não foi possível adicionar a foto."), "erro");

            } catch (error) {
                mostrarMensagem("Erro de conexão com o servidor.", "erro");
                console.error(error);

            } finally {
                if (botao) {
                    botao.disabled = false;
                    botao.innerText = "Adicionar à galeria";
                }
            }
        }

        async function removerFotoGaleria(carroId, fotoId) {
            const usuario = getUsuarioLogado();

            if (!usuario) {
                mostrarMensagem("Faça login para remover fotos da galeria.", "aviso");
                return;
            }

            const confirmar = confirm("Remover esta foto da galeria?");

            if (!confirmar) {
                return;
            }

            try {
                const res = await fetch(`${API_URL}/carros/${carroId}/fotos/${fotoId}?usuario_id=${usuario.id}`, {
                    method: 'DELETE'
                });

                const resposta = await res.json();

                if (res.ok) {
                    mostrarMensagem(resposta.mensagem || "Foto removida da galeria.", "sucesso");
                    carregarGaleriaProjeto(carroId, true);
                    return;
                }

                mostrarMensagem("Erro: " + (resposta.erro || "Não foi possível remover a foto."), "erro");

            } catch (error) {
                mostrarMensagem("Erro de conexão com o servidor.", "erro");
                console.error(error);
            }
        }

        const evolucoesDiarioCache = {};

        async function carregarEvolucoes(carroId, listaId = 'lista-evolucoes') {
            const lista = document.getElementById(listaId);

            if (!lista) {
                return;
            }

            try {
                const res = await fetch(`${API_URL}/carros/${carroId}/evolucoes`);
                const evolucoes = await res.json();

                if (!res.ok) {
                    lista.innerHTML = '<div class="evolucao-vazio">Não foi possível carregar o diário.</div>';
                    return;
                }

                if (!Array.isArray(evolucoes) || evolucoes.length === 0) {
                    lista.innerHTML = '<div class="evolucao-vazio">Ainda não há atualizações neste projeto.</div>';
                    return;
                }

                const usuario = getUsuarioLogado();

                lista.innerHTML = evolucoes.map(evolucao => {
                    evolucoesDiarioCache[evolucao.id] = evolucao;

                    const descricao = textoFeedbackSeguro(evolucao.descricao).replace(/\n/g, '<br>');
                    const imagem = evolucao.imagem_url ? `${API_URL}/uploads/${evolucao.imagem_url}` : '';
                    const podeGerenciar = usuario && String(usuario.id) === String(evolucao.usuario_id);

                    return `
                        <article class="evolucao-item">
                            <div class="evolucao-ponto"></div>

                            <div class="evolucao-conteudo">
                                <div class="evolucao-meta">
                                    <strong>${textoFeedbackSeguro(evolucao.titulo)}</strong>
                                    <span>${formatarTempoRelativo(evolucao.criado_em)}</span>
                                </div>

                                ${imagem ? `
                                    <img
                                        src="${imagem}"
                                        alt="Imagem da evolução do projeto"
                                        class="evolucao-imagem"
                                    >
                                ` : ''}

                                <p>${descricao}</p>

                                ${podeGerenciar ? `
                                    <div class="evolucao-acoes">
                                        <button
                                            type="button"
                                            class="btn-editar-evolucao"
                                            onclick="editarEvolucao(${carroId}, ${evolucao.id}, '${listaId}')"
                                        >
                                            Editar
                                        </button>

                                        <button
                                            type="button"
                                            class="btn-remover-evolucao"
                                            onclick="removerEvolucao(${carroId}, ${evolucao.id}, '${listaId}')"
                                        >
                                            Remover
                                        </button>
                                    </div>
                                ` : ''}
                            </div>
                        </article>
                    `;
                }).join('');

            } catch (error) {
                lista.innerHTML = '<div class="evolucao-vazio">Erro ao carregar o diário.</div>';
                console.error(error);
            }
        }

        async function enviarEvolucao(event, carroId, listaId = 'lista-evolucoes') {
            event.preventDefault();

            const usuario = getUsuarioLogado();

            if (!usuario) {
                mostrarMensagem("Faça login para registrar uma evolução.", "aviso");
                return;
            }

            const inputTitulo = document.getElementById('input-evolucao-titulo');
            const inputDescricao = document.getElementById('input-evolucao-descricao');
            const inputImagem = document.getElementById('input-evolucao-imagem');

            const titulo = inputTitulo.value.trim();
            const descricao = inputDescricao.value.trim();
            const imagem = inputImagem && inputImagem.files.length > 0
                ? inputImagem.files[0]
                : null;

            if (!titulo) {
                mostrarMensagem("Digite um título para a evolução.", "aviso");
                return;
            }

            if (!descricao) {
                mostrarMensagem("Digite uma descrição para a evolução.", "aviso");
                return;
            }

            if (imagem) {
                const tamanhoMaximoImagem = 5 * 1024 * 1024;
                const formatosPermitidos = ['image/png', 'image/jpeg', 'image/webp'];
                const extensoesPermitidas = ['png', 'jpg', 'jpeg', 'webp'];
                const extensao = imagem.name.split('.').pop().toLowerCase();

                if (
                    !formatosPermitidos.includes(imagem.type) ||
                    !extensoesPermitidas.includes(extensao)
                ) {
                    mostrarMensagem("Formato de imagem inválido. Use PNG, JPG, JPEG ou WEBP.", "aviso");
                    return;
                }

                if (imagem.size > tamanhoMaximoImagem) {
                    mostrarMensagem("Imagem muito pesada. Envie uma imagem com no máximo 5 MB.", "aviso");
                    return;
                }
            }

            const formData = new FormData();

            formData.append('usuario_id', usuario.id);
            formData.append('titulo', titulo);
            formData.append('descricao', descricao);

            if (imagem) {
                formData.append('imagem', imagem);
            }

            try {
                const res = await fetch(`${API_URL}/carros/${carroId}/evolucoes`, {
                    method: 'POST',
                    body: formData
                });

                const resposta = await res.json();

                if (res.ok) {
                    mostrarMensagem(resposta.mensagem || "Evolução registrada com sucesso!", "sucesso");

                    inputTitulo.value = '';
                    inputDescricao.value = '';

                    if (inputImagem) {
                        inputImagem.value = '';
                    }

                    const nomeImagem = document.getElementById('evolucao-imagem-nome');

                    if (nomeImagem) {
                        nomeImagem.textContent = 'Nenhum arquivo';
                    }

                    carregarEvolucoes(carroId, listaId);
                    return;
                }

                mostrarMensagem("Erro: " + (resposta.erro || "Não foi possível registrar a evolução."), "erro");

            } catch (error) {
                mostrarMensagem("Erro de conexão com o servidor.", "erro");
                console.error(error);
            }
        }

        async function editarEvolucao(carroId, evolucaoId, listaId = 'lista-evolucoes') {
            const usuario = getUsuarioLogado();

            if (!usuario) {
                mostrarMensagem("Faça login para editar evoluções.", "aviso");
                return;
            }

            const evolucao = evolucoesDiarioCache[evolucaoId];

            if (!evolucao) {
                mostrarMensagem("Não foi possível encontrar esta evolução.", "erro");
                return;
            }

            const novoTitulo = prompt("1/2 - Edite o título da evolução:", evolucao.titulo || "");

            if (novoTitulo === null) {
                return;
            }

            const novaDescricao = prompt("2/2 - Edite a descrição da evolução:", evolucao.descricao || "");

            if (novaDescricao === null) {
                return;
            }

            const titulo = novoTitulo.trim();
            const descricao = novaDescricao.trim();

            if (!titulo) {
                mostrarMensagem("Digite um título para a evolução.", "aviso");
                return;
            }

            if (!descricao) {
                mostrarMensagem("Digite uma descrição para a evolução.", "aviso");
                return;
            }

            if (titulo.length > 120) {
                mostrarMensagem("O título deve ter no máximo 120 caracteres.", "aviso");
                return;
            }

            try {
                const res = await fetch(`${API_URL}/carros/${carroId}/evolucoes/${evolucaoId}`, {
                    method: 'PUT',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        usuario_id: usuario.id,
                        titulo,
                        descricao
                    })
                });

                const resposta = await res.json();

                if (res.ok) {
                    mostrarMensagem(resposta.mensagem || "Evolução atualizada com sucesso!", "sucesso");
                    carregarEvolucoes(carroId, listaId);
                    return;
                }

                mostrarMensagem("Erro: " + (resposta.erro || "Não foi possível editar a evolução."), "erro");

            } catch (error) {
                mostrarMensagem("Erro de conexão com o servidor.", "erro");
                console.error(error);
            }
        }


        async function removerEvolucao(carroId, evolucaoId, listaId = 'lista-evolucoes') {
            const usuario = getUsuarioLogado();

            if (!usuario) {
                mostrarMensagem("Faça login para remover evoluções.", "aviso");
                return;
            }

            const confirmar = confirm("Remover esta evolução do diário?");

            if (!confirmar) {
                return;
            }

            try {
                const res = await fetch(`${API_URL}/carros/${carroId}/evolucoes/${evolucaoId}?usuario_id=${encodeURIComponent(usuario.id)}`, {
                    method: 'DELETE'
                });

                const resposta = await res.json();

                if (res.ok) {
                    mostrarMensagem(resposta.mensagem || "Evolução removida do diário.", "sucesso");
                    carregarEvolucoes(carroId, listaId);
                    return;
                }

                mostrarMensagem("Erro: " + (resposta.erro || "Não foi possível remover a evolução."), "erro");

            } catch (error) {
                mostrarMensagem("Erro de conexão com o servidor.", "erro");
                console.error(error);
            }
        }

        function restaurarScrollBodySeNaoHouverModalAberto() {
            const modalProjeto = document.getElementById('modal-projeto');
            const modalEquipe = document.getElementById('modal-minha-equipe');
            const garagemCompletaAberta = document.querySelector('.garagem-completa-overlay');

            const projetoAberto = modalProjeto && modalProjeto.style.display === 'block';
            const equipeAberta = modalEquipe && modalEquipe.style.display === 'block';

            if (!projetoAberto && !equipeAberta && !garagemCompletaAberta) {
                document.body.style.overflow = "";
            }
        }

        function fecharModalProjeto() {
            const modal = document.getElementById('modal-projeto');
            const modalContent = document.getElementById('modal-content');
            const equipeIdParaReabrir = equipeParaReabrirAposProjeto;
            const garagemCompletaParaReabrir = garagemCompletaParaReabrirAposProjeto;
            const perfilIdParaReabrir = perfilParaReabrirAposProjeto;

            equipeParaReabrirAposProjeto = null;
            garagemCompletaParaReabrirAposProjeto = null;
            perfilParaReabrirAposProjeto = null;

            if (perfilIdParaReabrir) {
                if (modalContent) {
                    modalContent.classList.add("trocando-conteudo");
                    modalContent.style.visibility = "visible";
                }

                abrirPerfil(perfilIdParaReabrir);
                return;
            }

            if (equipeIdParaReabrir) {
                if (modalContent) {
                    modalContent.classList.add("trocando-conteudo");
                    modalContent.style.visibility = "visible";
                }

                setTimeout(() => {
                    resetarScrollModalProjeto();

                    modal.style.display = "none";

                    if (modalContent) {
                        modalContent.classList.remove("trocando-conteudo");
                        modalContent.style.visibility = "visible";
                    }

                    abrirEquipe(equipeIdParaReabrir);
                }, 120);

                return;
            }

            resetarScrollModalProjeto();

            modal.style.display = "none";

            if (!equipeIdParaReabrir && !garagemCompletaParaReabrir && !perfilIdParaReabrir) {
                restaurarScrollBodySeNaoHouverModalAberto();
            }

            if (modalContent) {
                modalContent.classList.remove("trocando-conteudo");
                modalContent.style.visibility = "visible";
            }

            setTimeout(resetarScrollModalProjeto, 0);

            if (garagemCompletaParaReabrir) {
                abrirEquipe(garagemCompletaParaReabrir.clubeId);
                abrirGaragemCompletaEquipe(
                    garagemCompletaParaReabrir.clubeId,
                    garagemCompletaParaReabrir.nomeEquipe
                );
                return;
            }

            if (perfilIdParaReabrir) {
                abrirPerfil(perfilIdParaReabrir);
            }
        }

        const modalProjeto = document.getElementById('modal-projeto');

        if (modalProjeto) {
            modalProjeto.addEventListener('click', function(event) {
                if (event.target === modalProjeto) {
                    fecharModalProjeto();
                }
            });
        }

        function resetarScrollModalProjeto() {
            const modal = document.getElementById('modal-projeto');
            const modalContent = document.getElementById('modal-content');

            if (!modal) {
                return;
            }

            modal.scrollTop = 0;

            if (modalContent) {
                modalContent.scrollTop = 0;
            }

            requestAnimationFrame(() => {
                modal.scrollTop = 0;

                if (modalContent) {
                    modalContent.scrollTop = 0;
                }

                requestAnimationFrame(() => {
                    modal.scrollTop = 0;

                    if (modalContent) {
                        modalContent.scrollTop = 0;
                    }
                });
            });

            setTimeout(() => {
                modal.scrollTop = 0;

                if (modalContent) {
                    modalContent.scrollTop = 0;
                }
            }, 120);
        }

        function prepararEdicao(carro) {
            if (!usuarioEDono(carro)) {
                mostrarMensagem("Você não tem permissão para editar este projeto.", "erro");
                return;
            }

            const container = document.getElementById('container-form');
            const botaoToggle = document.querySelector('.btn-toggle-form');

            if (container) {
                container.style.display = 'block';
            }

            if (botaoToggle) {
                botaoToggle.innerText = 'Fechar formulário';
            }

            document.getElementById('input-id').value = carro.id;
            document.getElementById('input-dono').value = carro.nome_dono;
            document.getElementById('input-modelo').value = carro.modelo;
            document.getElementById('input-ano').value = carro.ano;
            document.getElementById('input-cor').value = carro.cor;
            document.getElementById('input-placa').value = carro.placa || '';
            document.getElementById('input-historia').value = carro.historia || '';
            document.getElementById('input-suspensao').value = carro.tipo_suspensao;
            document.getElementById('input-aro').value = carro.aro_roda;
            document.getElementById('input-motor').value = carro.motor || '';
            document.getElementById('input-cambio').value = carro.cambio || '';
            const combustiveisSelecionados = String(carro.combustivel || '')
                .split(',')
                .map(combustivel => combustivel.trim())
                .filter(Boolean);

            document.querySelectorAll('input[name="input-combustivel"]').forEach(input => {
                input.checked = combustiveisSelecionados.includes(input.value);
            });
            document.getElementById('input-potencia-estimada').value = carro.potencia_estimada || '';
            document.getElementById('input-preparacao').value = carro.preparacao || '';
            document.getElementById('input-status-projeto').value = carro.status_projeto || '';

            document.getElementById('btn-submit').innerText = "Confirmar Alterações";
            document.getElementById('btn-cancelar-edicao').style.display = "block";

            document.getElementById('titulo-form').innerText = "Editando Projeto";
            document.getElementById('container-form').style.borderColor = "#ff4757";
            document.getElementById('container-form').scrollIntoView({
                behavior: 'smooth',
                block: 'start'
            });

            window.scrollTo({ top: 0, behavior: 'smooth' });
        }

        document.getElementById('form-carro').addEventListener('submit', async function(e) {
            e.preventDefault();

            const usuario = getUsuarioLogado();

            if (!usuario) {
                mostrarMensagem("Faça login para cadastrar um projeto.", "aviso");
                return;
            }

            const btnSubmit = document.getElementById('btn-submit');
            const id = document.getElementById('input-id').value;

            const formData = new FormData();

            formData.append('usuario_id', usuario.id);
            formData.append('nome_dono', document.getElementById('input-dono').value.trim());
            formData.append('modelo', document.getElementById('input-modelo').value.trim());
            formData.append('ano', document.getElementById('input-ano').value);
            formData.append('cor', document.getElementById('input-cor').value.trim());
            formData.append('placa', document.getElementById('input-placa').value.trim());
            formData.append('historia', document.getElementById('input-historia').value.trim());
            formData.append('tipo_suspensao', document.getElementById('input-suspensao').value);
            formData.append('aro_roda', document.getElementById('input-aro').value);
            formData.append('motor', document.getElementById('input-motor').value.trim());
            formData.append('cambio', document.getElementById('input-cambio').value.trim());
            const combustiveis = Array.from(document.querySelectorAll('input[name="input-combustivel"]:checked'))
                .map(input => input.value)
                .join(', ');

            formData.append('combustivel', combustiveis);
            formData.append('potencia_estimada', document.getElementById('input-potencia-estimada').value.trim());
            formData.append('preparacao', document.getElementById('input-preparacao').value.trim());
            formData.append('status_projeto', document.getElementById('input-status-projeto').value);

            const foto = document.getElementById('input-foto').files[0];

            if (foto) {
                const tamanhoMaximoImagem = 5 * 1024 * 1024;
                const formatosPermitidos = ['image/png', 'image/jpeg', 'image/webp'];
                const extensoesPermitidas = ['png', 'jpg', 'jpeg', 'webp'];
                const extensao = foto.name.split('.').pop().toLowerCase();

                if (
                    !formatosPermitidos.includes(foto.type) ||
                    !extensoesPermitidas.includes(extensao)
                ) {
                    mostrarMensagem("Formato de imagem inválido. Use PNG, JPG, JPEG ou WEBP.", "aviso");
                    return;
                }

                if (foto.size > tamanhoMaximoImagem) {
                    mostrarMensagem("Imagem muito pesada. Envie uma imagem com no máximo 5 MB.", "aviso");
                    return;
                }

                formData.append('foto', foto);
            }

            const url = id ? `${API_URL}/carros/${id}` : `${API_URL}/carros`;
            const metodo = id ? 'PUT' : 'POST';

            try {
                btnSubmit.disabled = true;
                btnSubmit.innerText = id ? "Salvando alterações..." : "Estacionando...";

                const res = await fetch(url, {
                    method: metodo,
                    body: formData
                });

                let resposta = {};

                try {
                    resposta = await res.json();
                } catch {
                    resposta = {};
                }

                if (res.ok) {
                    mostrarMensagem("Operação realizada com sucesso!", "sucesso");
                    resetarFormulario();
                    carregarGaragem();

                    const container = document.getElementById('container-form');
                    const botaoToggle = document.querySelector('.btn-toggle-form');

                    if (container) {
                        container.style.display = 'none';
                    }

                    if (botaoToggle) {
                        botaoToggle.innerText = '+ Estacionar novo projeto';
                    }
                } else {
                    mostrarMensagem("Erro: " + (resposta.erro || "Não foi possível concluir a operação."), "erro");
                    btnSubmit.disabled = false;
                    btnSubmit.innerText = id ? "Confirmar Alterações" : "Estacionar na Garagem";
                }

            } catch (error) {
                mostrarMensagem("Erro de conexão com o servidor. Verifique se o Flask está rodando.", "erro");
                console.error(error);

                btnSubmit.disabled = false;
                btnSubmit.innerText = id ? "Confirmar Alterações" : "Estacionar na Garagem";
            }
        });

        function resetarFormulario() {
            const usuario = getUsuarioLogado();

            document.getElementById('form-carro').reset();

            document.getElementById('input-id').value = "";
            document.getElementById('input-historia').value = "";

            if (usuario) {
                document.getElementById('input-dono').value = usuario.nome;
            }

            document.getElementById('btn-submit').disabled = false;
            document.getElementById('btn-submit').innerText = "Estacionar na Garagem";
            document.getElementById('btn-cancelar-edicao').style.display = "none";

            document.getElementById('titulo-form').innerText = "Registrar Novo Projeto";
            document.getElementById('container-form').style.borderColor = "#555";

            document.getElementById('input-suspensao').selectedIndex = 0;
        }

        async function solicitarExclusao(id) {
            const usuario = getUsuarioLogado();

            if (!usuario) {
                mostrarMensagem("Faça login novamente.", "aviso");
                return;
            }

            const confirmar = await confirmarAcao({
                titulo: "Remover projeto?",
                mensagem: "Essa ação não pode ser desfeita. O projeto será removido da garagem.",
                textoConfirmar: "Remover projeto",
                textoCancelar: "Cancelar"
            });

            if (!confirmar) {
                return;
            }

            try {
                const res = await fetch(`${API_URL}/carros/${id}`, {
                    method: 'DELETE',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        usuario_id: usuario.id
                    })
                });

                let resposta = {};

                try {
                    resposta = await res.json();
                } catch {
                    resposta = {};
                }

                if (res.ok) {
                    mostrarMensagem("Projeto removido com sucesso!", "sucesso");
                    carregarGaragem();
                } else {
                    mostrarMensagem("Erro: " + (resposta.erro || "Não foi possível remover o projeto."), "erro");
                }

            } catch (error) {
                mostrarMensagem("Erro de conexão com o servidor. Verifique se o Flask está rodando.", "erro");
                console.error(error);
            }
        }

        async function carregarComentarios(carroId) {
            try {
                const res = await fetch(`${API_URL}/carros/${carroId}/comentarios`);
                const comentarios = await res.json();
                const usuario = getUsuarioLogado();

                const lista = document.getElementById('lista-comentarios');
                lista.innerHTML = '';

                atualizarBotaoComentarios(comentarios.length);

                if (!comentarios.length) {
                    lista.innerHTML = `<div style="color:#666;">Nenhum comentário ainda.</div>`;
                    return;
                }

                comentarios.forEach(c => {
                    const div = document.createElement('div');
                    const autorComentario = c.username_usuario
                        ? `@${c.username_usuario}`
                        : c.nome_usuario;

                    div.innerHTML = `
                        <div class="comentario-item">
                            <div class="comentario-topo">
                                ${c.usuario_id
                                    ? `<span class="comentario-autor" onclick="abrirPerfil(${c.usuario_id})">
                                        ${textoFeedbackSeguro(autorComentario)}
                                    </span>`
                                    : `<span class="comentario-autor">
                                        ${textoFeedbackSeguro(autorComentario)}
                                    </span>`
                                }

                                <div style="display: flex; gap: 8px; align-items: center;">
                                    <span class="comentario-data" title="${new Date(c.criado_em).toLocaleString()}">
                                        ${formatarTempoRelativo(c.criado_em)}
                                    </span>

                                    ${usuario && String(usuario.id) === String(c.usuario_id) ? `
                                        <button 
                                            type="button" 
                                            class="btn-remover-comentario" 
                                            onclick="excluirComentario(${c.id}, ${carroId})"
                                        >
                                            Remover
                                        </button>
                                    ` : ''}
                                </div>
                            </div>

                            <div class="comentario-texto">
                                ${c.texto}
                            </div>
                        </div>
                    `;

                    lista.appendChild(div);
                });

            } catch (error) {
                console.error(error);
            }
        }

        async function enviarComentario(carroId) {
            const usuario = getUsuarioLogado();

            if (!usuario) {
                mostrarMensagem("Faça login para comentar.", "aviso");
                return;
            }

            const input = document.getElementById('input-comentario');
            const texto = input.value.trim();

            if (!texto) {
                mostrarMensagem("Digite um comentário.", "aviso");
                return;
            }

            try {
                const res = await fetch(`${API_URL}/carros/${carroId}/comentarios`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        usuario_id: usuario.id,
                        texto: texto
                    })
                });

                if (res.ok) {
                    input.value = '';
                    carregarComentarios(carroId);
                    carregarGaragem();
                } else {
                    const erro = await res.json();
                    mostrarMensagem(erro.erro || "Erro ao comentar.", "erro");
                }

            } catch (error) {
                console.error(error);
                mostrarMensagem("Erro de conexão.", "erro");
            }
        }

        async function excluirComentario(comentarioId, carroId) {
            const usuario = getUsuarioLogado();

            if (!usuario) {
                mostrarMensagem("Você precisa estar logado para remover um comentário.", "aviso");
                return;
            }

            const confirmar = await confirmarAcao({
                titulo: "Remover comentário?",
                mensagem: "Esse comentário será removido permanentemente.",
                textoConfirmar: "Remover comentário",
                textoCancelar: "Cancelar"
            });

            if (!confirmar) {
                return;
            }

            try {
                const res = await fetch(`${API_URL}/comentarios/${comentarioId}`, {
                    method: 'DELETE',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        usuario_id: usuario.id
                    })
                });

                const resposta = await res.json();

                if (res.ok) {
                    carregarComentarios(carroId);
                    carregarGaragem();
                } else {
                    mostrarMensagem(resposta.erro || "Erro ao remover comentário.", "erro");
                }

            } catch (error) {
                console.error(error);
                mostrarMensagem("Erro de conexão.", "erro");
            }
        }

        function obterUsuarioLogado() {
            const usuarioSalvo = localStorage.getItem('usuario');
            const usuarioLogadoSalvo = localStorage.getItem('usuarioLogado');

            if (usuarioSalvo) {
                return JSON.parse(usuarioSalvo);
            }

            if (usuarioLogadoSalvo) {
                return JSON.parse(usuarioLogadoSalvo);
            }

            if (typeof usuario !== 'undefined' && usuario) {
                return usuario;
            }

            return null;
        }

        function obterUsuarioAtualParaPedidoEquipe() {
            if (typeof usuarioAtual !== 'undefined' && usuarioAtual && usuarioAtual.id) {
                return usuarioAtual;
            }

            if (typeof usuarioLogado !== 'undefined' && usuarioLogado && usuarioLogado.id) {
                return usuarioLogado;
            }

            const chavesPossiveis = ['usuario', 'usuarioLogado', 'usuario_atual'];

            for (const chave of chavesPossiveis) {
                const valor = localStorage.getItem(chave);

                if (!valor) continue;

                try {
                    const usuario = JSON.parse(valor);

                    if (usuario && usuario.id) {
                        return usuario;
                    }
                } catch (erro) {
                    console.warn(`Não foi possível ler ${chave} do localStorage`, erro);
                }
            }

            return null;
        }

        async function carregarPedidosPendentesUsuario(usuarioId) {
            try {
                const resposta = await fetch(`${API_URL}/usuarios/${usuarioId}/pedidos-clube?status=pendente`);

                if (!resposta.ok) {
                    console.warn('Não foi possível carregar pedidos pendentes do usuário.');
                    return [];
                }

                const pedidos = await resposta.json();

                if (!Array.isArray(pedidos)) {
                    return [];
                }

                return pedidos;
            } catch (erro) {
                console.error('Erro ao carregar pedidos pendentes do usuário:', erro);
                return [];
            }
        }

        async function pedirEntradaEquipe(clubeId, botao) {
            const usuario = obterUsuarioAtualParaPedidoEquipe();

            if (!usuario || !usuario.id) {
                mostrarMensagem('Você precisa estar logado para pedir para entrar em uma equipe.', 'aviso');
                return;
            }

            const textoOriginal = botao ? botao.textContent : 'Pedir para entrar';

            if (botao) {
                botao.disabled = true;
                botao.textContent = 'Enviando...';
            }

            try {
                const resposta = await fetch(`${API_URL}/clubes/${clubeId}/pedidos`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        usuario_id: usuario.id
                    })
                });

                const dados = await resposta.json();

                if (!resposta.ok) {
                    const mensagemErro = dados.erro || 'Não foi possível enviar o pedido.';

                    if (botao) {
                        if (mensagemErro.includes('já enviou')) {
                            botao.textContent = 'Pedido pendente';
                            botao.classList.add('pedido-enviado', 'pedido-pendente');
                            botao.disabled = true;
                        } else if (mensagemErro.includes('já participa')) {
                            botao.textContent = 'Você já está em uma equipe';
                        } else {
                            botao.textContent = textoOriginal;
                            botao.disabled = false;
                        }
                    }

                    mostrarMensagem(mensagemErro, 'erro');
                    return;
                }

                if (botao) {
                    botao.classList.remove('pedido-enviado', 'pedido-pendente');
                    botao.classList.add('btn-principal', 'btn-pedir-equipe', 'btn-pedido-pendente');
                    botao.disabled = false;
                    botao.textContent = 'Cancelar pedido';

                    botao.onclick = (event) => {
                        event.stopPropagation();
                        cancelarPedidoEquipe(clubeId, botao);
                    };
                }

                mostrarMensagem(dados.mensagem || 'Pedido enviado com sucesso.', 'sucesso');
            } catch (erro) {
                console.error('Erro ao pedir entrada na equipe:', erro);

                if (botao) {
                    botao.disabled = false;
                    botao.textContent = textoOriginal;
                }

                mostrarMensagem('Erro ao enviar pedido. Tente novamente.', 'erro');
            }
        }

        async function cancelarPedidoEquipe(clubeId, botao = null) {
            const usuario = getUsuarioLogado();

            if (!usuario || !usuario.id) {
                mostrarMensagem("Faça login para cancelar o pedido.", "aviso");
                return;
            }

            const confirmar = await confirmarAcao({
                titulo: "Cancelar pedido?",
                mensagem: "Seu pedido pendente para entrar nesta equipe será cancelado.",
                textoConfirmar: "Cancelar pedido",
                textoCancelar: "Voltar"
            });

            if (!confirmar) {
                return;
            }

            const textoOriginal = botao ? botao.textContent : "Cancelar pedido";

            if (botao) {
                botao.disabled = true;
                botao.textContent = "Cancelando...";
            }

            try {
                const resposta = await fetch(`${API_URL}/clubes/${clubeId}/pedidos`, {
                    method: "DELETE",
                    headers: {
                        "Content-Type": "application/json"
                    },
                    body: JSON.stringify({
                        usuario_id: usuario.id
                    })
                });

                const dados = await resposta.json();

                if (!resposta.ok) {
                    mostrarMensagem(dados.erro || "Erro ao cancelar pedido.", "erro");

                    if (botao) {
                        botao.disabled = false;
                        botao.textContent = textoOriginal;
                    }

                    return;
                }

                mostrarMensagem(dados.mensagem || "Pedido cancelado com sucesso.", "sucesso");

                if (botao) {
                    botao.classList.remove('btn-pedido-pendente', 'pedido-pendente', 'pedido-enviado');
                    botao.classList.add('btn-principal', 'btn-pedir-equipe');
                    botao.disabled = false;
                    botao.textContent = "Pedir para entrar";

                    botao.onclick = (event) => {
                        event.stopPropagation();
                        pedirEntradaEquipe(clubeId, botao);
                    };
                }
            } catch (erro) {
                console.error("Erro ao cancelar pedido:", erro);
                mostrarMensagem("Erro de conexão ao cancelar pedido.", "erro");

                if (botao) {
                    botao.disabled = false;
                    botao.textContent = textoOriginal;
                }
            }
        }

        function abrirMinhaEquipe() {
            const modal = document.getElementById('modal-equipe');
            const container = document.getElementById('conteudo-equipe');

            if (!modal) {
                mostrarMensagem('Modal de equipe não encontrado.', 'erro');
                return;
            }

            modal.style.display = 'block';

            if (container) {
                container.innerHTML = '<p>Carregando equipe...</p>';
            }

            carregarMinhaEquipe();
        }

        function fecharMinhaEquipe() {
            const modal = document.getElementById('modal-equipe');

            if (modal) {
                modal.style.display = 'none';
            }
            restaurarScrollBodySeNaoHouverModalAberto();
        }

        function textoSeguro(valor) {
            const div = document.createElement('div');
            div.textContent = valor || '';
            return div.innerHTML;
        }

        async function abrirEquipe(clubeId) {
            const modal = document.getElementById('modal-equipe');
            const titulo = document.getElementById('titulo-modal-equipe');
            const container = document.getElementById('conteudo-equipe');

            if (!modal || !container) {
                mostrarMensagem('Modal de equipe não encontrado.', 'erro');
                return;
            }

            modal.style.display = 'block';

            if (titulo) {
                titulo.textContent = 'Equipe';
            }

            container.innerHTML = '<p>Carregando equipe...</p>';

            try {
                const resposta = await fetch(`${API_URL}/clubes/${clubeId}`);

                if (!resposta.ok) {
                    container.innerHTML = '<p>Erro ao carregar equipe.</p>';
                    return;
                }

                const equipe = await resposta.json();
                const membros = Array.isArray(equipe.membros) ? equipe.membros : [];

                const membrosHtml = membros.length
                    ? membros.map(membro => {
                        const nome = textoSeguro(membro.nome || 'Usuário');
                        const username = textoSeguro(membro.username || 'usuario');
                        const inicial = (membro.nome || membro.username || '?').charAt(0).toUpperCase();

                        const avatarUrl = membro.avatar_url
                            ? (
                                membro.avatar_url.startsWith('http')
                                    ? membro.avatar_url
                                    : `${API_URL}/uploads/${membro.avatar_url}`
                            )
                            : '';

                        const avatarHtml = avatarUrl
                            ? `<img class="equipe-membro-avatar" src="${avatarUrl}" alt="Avatar de ${nome}">`
                            : `<div class="equipe-membro-avatar-fallback">${inicial}</div>`;

                        return `
                            <div class="equipe-membro" onclick="fecharMinhaEquipe(); abrirPerfil(${membro.id})">
                                ${avatarHtml}
                                <div class="equipe-membro-info">
                                    <strong>${nome}</strong>
                                    <span>@${username}</span>
                                </div>
                            </div>
                        `;
                    }).join('')
                    : '<p>Nenhum membro encontrado.</p>';

                container.innerHTML = `
                    <div class="equipe-detalhe-header">
                        <h3>${textoSeguro(equipe.nome)}</h3>
                        <p>${textoSeguro(equipe.descricao || 'Equipe sem descrição.')}</p>

                        <div class="equipe-meta">
                            Criado por @${textoSeguro(equipe.username_dono || 'usuario')}
                        </div>

                        <div class="equipe-meta">
                            Membros: ${membros.length}
                        </div>
                    </div>

                    <div class="equipe-card">
                        <h3>Membros</h3>
                        <div class="equipe-membros-lista">
                            ${membrosHtml}
                        </div>
                    </div>

                    <div id="pedidos-equipe-container"></div>

                    <div class="equipe-garagem-futura garagem-equipe-bloco">
                        <div class="equipe-garagem-futura-topo">
                            <div class="equipe-garagem-icone">🏎️</div>

                            <div class="equipe-garagem-texto">
                                <h3>Garagem da equipe</h3>
                                <p>Projetos cadastrados pelos membros da equipe.</p>
                            </div>
                        </div>

                        <div id="garagem-equipe-lista" class="garagem-equipe-lista">
                            <p class="garagem-equipe-vazio">
                                Carregando projetos da equipe...
                            </p>
                        </div>

                        <div id="garagem-equipe-acoes" class="garagem-equipe-acoes"></div>
                    </div>
                `;

            const usuario = obterUsuarioAtualParaPedidoEquipe();

            if (usuario && String(usuario.id) === String(equipe.dono_id)) {
                carregarPedidosEquipe(equipe.id);
            }

            carregarGaragemEquipe(equipe.id, equipe.nome);

            } catch (erro) {
                console.error('Erro ao abrir equipe:', erro);
                container.innerHTML = '<p>Erro ao carregar equipe. Verifique se o servidor Flask está rodando.</p>';
            }
        }

        function montarCardGaragemEquipe(projeto) {
            const foto = projeto.foto_url
                ? `${API_URL}/uploads/${projeto.foto_url}`
                : '';

            const detalhesProjeto = [
                projeto.aro_roda ? `Aro ${projeto.aro_roda}` : null,
                projeto.cor
            ].filter(Boolean).join(' • ');

            const username = projeto.username_usuario || 'usuario';

            return `
                <div class="garagem-equipe-card" data-projeto-id="${projeto.id}">
                    <div class="garagem-equipe-media">
                        ${
                            foto
                                ? `<img src="${foto}" alt="" class="garagem-equipe-img">`
                                : `<div class="garagem-equipe-sem-foto">SEM FOTO</div>`
                        }

                        <div class="garagem-equipe-overlay"></div>

                        <span class="garagem-equipe-badge">
                            Equipe
                        </span>
                    </div>

                    <div class="garagem-equipe-info">
                        <div class="garagem-equipe-titulo">
                            <strong>${projeto.modelo || 'Projeto sem nome'}</strong>
                            <span>${projeto.ano || 'Projeto'}</span>
                        </div>

                        <p class="garagem-equipe-spec">
                            ${detalhesProjeto || 'Detalhes do projeto'}
                        </p>

                        <div class="garagem-equipe-rodape">
                            <span class="garagem-equipe-dono">@${username}</span>
                        </div>
                    </div>
                </div>
            `;
        }

        async function carregarGaragemEquipe(clubeId, nomeEquipe = 'Equipe') {
            const container = document.getElementById('garagem-equipe-lista');
            const acoesContainer = document.getElementById('garagem-equipe-acoes');

            if (!container) {
                return;
            }

            if (acoesContainer) {
                acoesContainer.innerHTML = '';
            }

            container.innerHTML = `
                <div class="garagem-equipe-vazio garagem-equipe-loading">
                    <span>🏁</span>
                    <strong>Carregando garagem da equipe...</strong>
                    <p>Buscando os projetos cadastrados pelos membros.</p>
                </div>
            `;

            const usuario = getUsuarioLogado();
            const params = new URLSearchParams();

            if (usuario && usuario.id) {
                params.append('usuario_id', usuario.id);
            }

            try {
                const resposta = await fetch(`${API_URL}/clubes/${clubeId}/carros?${params.toString()}`);
                const projetos = await resposta.json();

                if (!resposta.ok) {
                    container.innerHTML = `
                        <div class="garagem-equipe-vazio">
                            <span>⚠️</span>
                            <strong>Não foi possível carregar a garagem</strong>
                            <p>Tente abrir a equipe novamente em alguns instantes.</p>
                        </div>
                    `;
                    return;
                }

                if (!Array.isArray(projetos) || projetos.length === 0) {
                    container.innerHTML = `
                        <div class="garagem-equipe-vazio">
                            <span>🏎️</span>
                            <strong>Nenhum projeto na garagem ainda</strong>
                            <p>Quando os membros cadastrarem projetos, eles vão aparecer juntos aqui.</p>
                        </div>
                    `;
                    return;
                }

                const projetosPreview = projetos.slice(0, 3);

                container.innerHTML = projetosPreview.map((projeto) => {
                    return montarCardGaragemEquipe(projeto);
                }).join('');

                if (acoesContainer && projetos.length > projetosPreview.length) {
                    acoesContainer.innerHTML = `
                        <button
                            type="button"
                            class="btn-garagem-completa ui-pill"
                            onclick="abrirGaragemCompletaEquipe(${clubeId}, '${String(nomeEquipe || 'Equipe').replace(/'/g, "\\'")}')"
                        >
                            Ver garagem completa
                        </button>
                    `;
                }

                container.querySelectorAll('.garagem-equipe-card').forEach((card) => {
                    card.addEventListener('click', () => {
                        const projeto = projetos.find((item) => {
                            return String(item.id) === String(card.dataset.projetoId);
                        });

                        if (!projeto) {
                            return;
                        }

                        equipeParaReabrirAposProjeto = clubeId;
                        fecharMinhaEquipe();
                        abrirModalProjeto(projeto);
                    });
                });
            } catch (erro) {
                console.error('Erro ao carregar garagem da equipe:', erro);

                container.innerHTML = `
                    <p class="garagem-equipe-vazio">
                        Erro ao carregar a garagem da equipe.
                    </p>
                `;
            }
        }

        async function abrirGaragemCompletaEquipe(clubeId, nomeEquipe = 'Equipe') {
            const overlayExistente = document.querySelector('.garagem-completa-overlay');

            if (overlayExistente) {
                overlayExistente.remove();
            }

            const overlay = document.createElement('div');
            overlay.className = 'garagem-completa-overlay';

            overlay.innerHTML = `
                <div class="garagem-completa-modal">
                    <div class="garagem-completa-header">
                        <div>
                            <span>Garagem coletiva</span>
                            <h2>${textoFeedbackSeguro(nomeEquipe)}</h2>
                            <p>Projetos cadastrados pelos membros da equipe.</p>
                        </div>

                        <button
                            type="button"
                            class="garagem-completa-fechar"
                            aria-label="Fechar garagem completa"
                        >
                            ×
                        </button>
                    </div>

                    <div id="garagem-completa-lista" class="garagem-completa-lista"></div>
                </div>
            `;

            document.body.appendChild(overlay);
            document.body.style.overflow = 'hidden';

            const fecharGaragemCompleta = () => {
                overlay.remove();
                restaurarScrollBodySeNaoHouverModalAberto();
            };

            overlay.querySelector('.garagem-completa-fechar').addEventListener('click', fecharGaragemCompleta);

            overlay.addEventListener('click', (event) => {
                if (event.target === overlay) {
                    fecharGaragemCompleta();
                }
            });

            const lista = overlay.querySelector('#garagem-completa-lista');

            try {
                const resposta = await fetch(`${API_URL}/clubes/${clubeId}/carros`);
                const projetos = await resposta.json();

                if (!resposta.ok) {
                    lista.innerHTML = `
                        <div class="garagem-equipe-vazio">
                            <span>⚠️</span>
                            <strong>Não foi possível carregar a garagem</strong>
                            <p>Tente abrir a equipe novamente em alguns instantes.</p>
                        </div>
                    `;
                    return;
                }

                if (!Array.isArray(projetos) || projetos.length === 0) {
                    lista.innerHTML = `
                        <div class="garagem-equipe-vazio">
                            <span>🏎️</span>
                            <strong>Nenhum projeto na garagem ainda</strong>
                            <p>Quando os membros cadastrarem projetos, eles vão aparecer juntos aqui.</p>
                        </div>
                    `;
                    return;
                }

                lista.innerHTML = projetos.map((projeto) => {
                    return montarCardGaragemEquipe(projeto);
                }).join('');

                lista.querySelectorAll('.garagem-equipe-card').forEach((card) => {
                    card.addEventListener('click', () => {
                        const projeto = projetos.find((item) => {
                            return String(item.id) === String(card.dataset.projetoId);
                        });

                        if (!projeto) {
                            return;
                        }

                        garagemCompletaParaReabrirAposProjeto = {
                            clubeId,
                            nomeEquipe
                        };

                        overlay.remove();
                        fecharMinhaEquipe();
                        abrirModalProjeto(projeto);
                    });
                });
            } catch (erro) {
                console.error('Erro ao carregar garagem completa da equipe:', erro);

                lista.innerHTML = `
                    <div class="garagem-equipe-vazio">
                        <span>⚠️</span>
                        <strong>Erro ao carregar garagem completa</strong>
                        <p>Verifique a conexão e tente novamente.</p>
                    </div>
                `;
            }
        }

        async function carregarPedidosEquipe(clubeId) {
            const container = document.getElementById('pedidos-equipe-container');
            const usuario = obterUsuarioAtualParaPedidoEquipe();

            if (!container || !usuario || !usuario.id) return;

            container.innerHTML = `
                <div class="pedidos-equipe-bloco">
                    <h3>Pedidos pendentes</h3>
                    <p>Carregando solicitações de entrada...</p>
                </div>
            `;

            try {
                const resposta = await fetch(`${API_URL}/clubes/${clubeId}/pedidos?usuario_id=${usuario.id}`);

                if (!resposta.ok) {
                    container.innerHTML = '';
                    return;
                }

                const pedidos = await resposta.json();

                if (!Array.isArray(pedidos) || pedidos.length === 0) {
                    container.innerHTML = `
                        <div class="pedidos-equipe-bloco">
                            <h3>Pedidos pendentes</h3>
                            <div class="pedidos-equipe-vazio">
                                Nenhum pedido pendente no momento.
                            </div>
                        </div>
                    `;
                    return;
                }

                const pedidosHtml = pedidos.map(pedido => `
                    <div class="pedido-equipe-item">
                        <div class="pedido-equipe-info">
                            <strong>${textoSeguro(pedido.nome)}</strong>
                            <span>@${textoSeguro(pedido.username || 'usuario')}</span>
                        </div>

                        <div class="pedido-equipe-acoes">
                            <button 
                                type="button" 
                                class="btn-aprovar-pedido"
                                onclick="aprovarPedidoEquipe(${pedido.id}, ${clubeId}, this)"
                            >
                                Aprovar
                            </button>

                            <button 
                                type="button" 
                                class="btn-recusar-pedido"
                                onclick="recusarPedidoEquipe(${pedido.id}, ${clubeId}, this)"
                            >
                                Recusar
                            </button>
                        </div>
                    </div>
                `).join('');

                container.innerHTML = `
                    <div class="pedidos-equipe-bloco">
                        <h3>Pedidos pendentes</h3>
                        <p>Analise quem pode entrar na equipe.</p>
                        ${pedidosHtml}
                    </div>
                `;
            } catch (erro) {
                console.error('Erro ao carregar pedidos da equipe:', erro);
                container.innerHTML = '';
            }
        }

        async function aprovarPedidoEquipe(pedidoId, clubeId, botao) {
            const usuario = obterUsuarioAtualParaPedidoEquipe();

            if (!usuario || !usuario.id) {
                mostrarMensagem('Você precisa estar logado para aprovar pedidos.', 'aviso');
                return;
            }

            const confirmar = await confirmarAcao({
                titulo: "Aprovar pedido?",
                mensagem: "Este usuário será adicionado à equipe.",
                textoConfirmar: "Aprovar",
                textoCancelar: "Cancelar"
            });

            if (!confirmar) {
                return;
            }

            const textoOriginal = botao ? botao.textContent : 'Aprovar';

            if (botao) {
                botao.disabled = true;
                botao.textContent = 'Aprovando...';
            }

            try {
                const resposta = await fetch(`${API_URL}/pedidos-clube/${pedidoId}/aprovar`, {
                    method: 'PUT',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        usuario_id: usuario.id
                    })
                });

                const dados = await resposta.json();

                if (!resposta.ok) {
                    mostrarMensagem(dados.erro || 'Não foi possível aprovar o pedido.', 'erro');

                    if (botao) {
                        botao.disabled = false;
                        botao.textContent = textoOriginal;
                    }

                    return;
                }

                mostrarMensagem(dados.mensagem || 'Pedido aprovado com sucesso.', 'sucesso');

                abrirEquipe(clubeId);
            } catch (erro) {
                console.error('Erro ao aprovar pedido:', erro);
                mostrarMensagem('Erro ao aprovar pedido. Tente novamente.', 'erro');

                if (botao) {
                    botao.disabled = false;
                    botao.textContent = textoOriginal;
                }
            }
        }

        async function recusarPedidoEquipe(pedidoId, clubeId, botao) {
            const usuario = obterUsuarioAtualParaPedidoEquipe();

            if (!usuario || !usuario.id) {
                mostrarMensagem('Você precisa estar logado para recusar pedidos.', 'aviso');
                return;
            }

            const confirmar = await confirmarAcao({
                titulo: "Recusar pedido?",
                mensagem: "O pedido de entrada será recusado.",
                textoConfirmar: "Recusar",
                textoCancelar: "Cancelar"
            });

            if (!confirmar) {
                return;
            }

            const textoOriginal = botao ? botao.textContent : 'Recusar';

            if (botao) {
                botao.disabled = true;
                botao.textContent = 'Recusando...';
            }

            try {
                const resposta = await fetch(`${API_URL}/pedidos-clube/${pedidoId}/recusar`, {
                    method: 'PUT',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        usuario_id: usuario.id
                    })
                });

                const dados = await resposta.json();

                if (!resposta.ok) {
                    mostrarMensagem(dados.erro || 'Não foi possível recusar o pedido.', 'erro');

                    if (botao) {
                        botao.disabled = false;
                        botao.textContent = textoOriginal;
                    }

                    return;
                }

                mostrarMensagem(dados.mensagem || 'Pedido recusado com sucesso.', 'sucesso');

                carregarPedidosEquipe(clubeId);
            } catch (erro) {
                console.error('Erro ao recusar pedido:', erro);
                mostrarMensagem('Erro ao recusar pedido. Tente novamente.', 'erro');

                if (botao) {
                    botao.disabled = false;
                    botao.textContent = textoOriginal;
                }
            }
        }

        async function carregarMinhaEquipe() {
            const container = document.getElementById('conteudo-equipe');
            const usuario = obterUsuarioLogado();

            if (!container) {
                console.error('Container conteudo-equipe não encontrado.');
                return;
            }

            if (!usuario) {
                container.innerHTML = '<p>Faça login para acessar sua equipe.</p>';
                return;
            }

            container.innerHTML = '<p>Carregando equipe...</p>';

            try {
                const respostaMinhaEquipe = await fetch(`${API_URL}/usuarios/${usuario.id}/clube`);

                if (!respostaMinhaEquipe.ok) {
                    container.innerHTML = '<p>Erro ao carregar sua equipe.</p>';
                    return;
                }

                const minhaEquipe = await respostaMinhaEquipe.json();

                if (minhaEquipe && minhaEquipe.id) {
                    abrirEquipe(minhaEquipe.id);
                    return;
                }

                const respostaClubes = await fetch(`${API_URL}/clubes`);

                if (!respostaClubes.ok) {
                    container.innerHTML = '<p>Erro ao buscar equipes no servidor.</p>';
                    return;
                }

                const clubes = await respostaClubes.json();

                if (!Array.isArray(clubes)) {
                    container.innerHTML = '<p>Resposta inesperada ao carregar equipes.</p>';
                    console.error('Resposta inesperada:', clubes);
                    return;
                }

                const clubesDetalhados = [];

                for (const clube of clubes) {
                    const respostaDetalhe = await fetch(`${API_URL}/clubes/${clube.id}`);

                    if (respostaDetalhe.ok) {
                        const detalhe = await respostaDetalhe.json();
                        clubesDetalhados.push(detalhe);
                    }
                }

                container.innerHTML = `
                    <p>Você ainda não participa de nenhuma equipe.</p>

                    <div class="equipe-acoes">
                        <button type="button" class="btn-equipe-principal" onclick="toggleFormEquipe()">
                            Criar equipe
                        </button>
                    </div>

                    <div id="form-equipe" class="form-equipe">
                        <input type="text" id="equipe-nome" placeholder="Nome da equipe">
                        <textarea id="equipe-descricao" placeholder="Descrição da equipe"></textarea>
                        <button type="button" class="btn-equipe-principal" onclick="criarEquipe()">
                            Criar
                        </button>
                    </div>

                    <h3>Equipes existentes</h3>
                    <div id="lista-equipes"></div>
                `;

                const lista = document.getElementById('lista-equipes');

                lista.classList.add('equipes-lista');
                lista.innerHTML = '';

                if (!clubes.length) {
                    lista.innerHTML = '<p>Nenhuma equipe criada ainda.</p>';
                    return;
                }

                const pedidosPendentes = await carregarPedidosPendentesUsuario(usuario.id);
                const clubesComPedidoPendente = new Set(
                    pedidosPendentes.map(pedido => String(pedido.clube_id))
                );

                clubes.forEach(clube => {
                    const card = document.createElement('div');
                    card.className = 'equipe-lista-card';

                    const totalMembros = clube.total_membros || 0;

                    const temPedidoPendente = clubesComPedidoPendente.has(String(clube.id));

                    const botaoPedidoHtml = temPedidoPendente
                        ? `
                            <button
                                type="button"
                                class="btn-principal btn-pedir-equipe btn-pedido-pendente"
                                onclick="event.stopPropagation(); cancelarPedidoEquipe(${clube.id}, this)"
                            >
                                Cancelar pedido
                            </button>
                        `
                        : `
                            <button 
                                type="button" 
                                class="btn-principal btn-pedir-equipe" 
                                onclick="event.stopPropagation(); pedirEntradaEquipe(${clube.id}, this)"
                            >
                                Pedir para entrar
                            </button>
                        `;

                    card.innerHTML = `
                        <h4>${textoSeguro(clube.nome)}</h4>

                        <p>${textoSeguro(clube.descricao || 'Equipe sem descrição.')}</p>

                        <div class="equipe-lista-meta">
                            <span>👤 Criado por @${textoSeguro(clube.username_dono || 'usuario')}</span>
                            <span>🏁 ${totalMembros} membro${Number(totalMembros) === 1 ? '' : 's'}</span>
                        </div>

                        ${botaoPedidoHtml}
                    `;

                    lista.appendChild(card);
                });

            } catch (erro) {
                console.error('Erro ao carregar equipe:', erro);
                container.innerHTML = '<p>Erro ao carregar informações da equipe. Verifique se o servidor Flask está rodando.</p>';
            }
        }

        function toggleFormEquipe() {
            const form = document.getElementById('form-equipe');

            if (form) {
                form.classList.toggle('ativo');
            }
        }

        async function criarEquipe() {
            const usuario = obterUsuarioLogado();
            const nome = document.getElementById('equipe-nome').value.trim();
            const descricao = document.getElementById('equipe-descricao').value.trim();

            if (!usuario) {
                mostrarMensagem('Faça login para criar uma equipe.', 'aviso');
                return;
            }

            if (!nome) {
                mostrarMensagem('Informe o nome da equipe.', 'aviso');
                return;
            }

            try {
                const resposta = await fetch('http://localhost:5000/clubes', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        usuario_id: usuario.id,
                        nome,
                        descricao
                    })
                });

                const dados = await resposta.json();

                if (!resposta.ok) {
                    mostrarMensagem(dados.erro || 'Erro ao criar equipe.', 'erro');
                    return;
                }

                mostrarMensagem('Equipe criada com sucesso!', 'sucesso');
                carregarMinhaEquipe();

            } catch (erro) {
                mostrarMensagem('Erro ao criar equipe.', 'erro');
            }
        }

        async function abrirPerfil(usuarioId) {
            const modal = document.getElementById('modal-projeto');
            const modalContent = document.getElementById('modal-content');
            const modalJaAberto = modal.style.display === "block";

            if (!modalJaAberto) {
                modal.style.display = "none";
                modalContent.innerHTML = "";
                modalContent.style.visibility = "hidden";
                resetarScrollModalProjeto();
            } else {
                modalContent.classList.add("trocando-conteudo");
            }

            document.body.style.overflow = "hidden";

            try {
                const usuarioLogadoAtual = getUsuarioLogado();
                const queryUsuarioLogado = usuarioLogadoAtual ? `?usuario_logado_id=${usuarioLogadoAtual.id}` : '';
                const resUser = await fetch(`${API_URL}/usuarios/${usuarioId}${queryUsuarioLogado}`);

                if (!resUser.ok) {
                    mostrarMensagem("Perfil não disponível.", "aviso");
                    return;
                }

                const usuario = await resUser.json();
                const usuarioLogado = usuarioLogadoAtual;
                const perfilProprio = usuarioLogado && String(usuarioLogado.id) === String(usuario.id);
                const resCarros = await fetch(`${API_URL}/usuarios/${usuarioId}/carros`);
                const carros = await resCarros.json();
                const inicialPerfil = usuario.nome ? usuario.nome.charAt(0).toUpperCase() : "?";
                const avatarSrc = usuario.avatar_url
                    ? (usuario.avatar_url.startsWith('http')
                        ? usuario.avatar_url
                        : `${API_URL}/uploads/${usuario.avatar_url}`)
                    : '';

                const avatarPerfil = avatarSrc
                    ? `<img src="${avatarSrc}" alt="" class="perfil-avatar">`
                    : `<div class="perfil-avatar-fallback">${inicialPerfil}</div>`;

                const bioPerfil = usuario.bio && usuario.bio.trim()
                    ? usuario.bio
                    : "Esse usuário ainda não adicionou uma bio.";

                const formularioEdicaoPerfil = perfilProprio ? `
                    <div class="perfil-edicao" id="perfil-edicao" style="display: none;">
                        <input
                            type="hidden"
                            id="perfil-avatar-atual"
                            value="${usuario.avatar_url || ''}"
                        >

                        <label class="perfil-label">
                            Foto de perfil
                        </label>

                        <label class="upload-container">
                            <span class="upload-btn">Escolher foto</span>
                            <span class="upload-nome" id="avatar-nome">Nenhum arquivo</span>

                            <input
                                type="file"
                                id="perfil-avatar-arquivo"
                                accept="image/png, image/jpeg, image/webp"
                                style="display: none;"
                            >
                        </label>

                        <textarea
                            id="perfil-bio"
                            maxlength="280"
                            placeholder="Escreva uma bio curta sobre você e sua garagem..."
                        >${usuario.bio || ''}</textarea>

                        <button
                            type="button"
                            class="btn-salvar-perfil"
                            onclick="salvarPerfil(${usuario.id})"
                        >
                            Salvar perfil
                        </button>
                    </div>
                ` : '';

                const botaoEditarPerfil = perfilProprio ? `
                    <button
                        type="button"
                        class="btn-editar-perfil"
                        onclick="mostrarEdicaoPerfil()"
                    >
                        Editar perfil
                    </button>
                ` : '';

                const botaoSeguirPerfil = !perfilProprio && usuarioLogado ? `
                    <button
                        type="button"
                        class="btn-seguir-perfil ${usuario.seguido_pelo_usuario ? 'seguindo' : ''}"
                        onclick="alternarSeguir(${usuario.id}, ${usuario.seguido_pelo_usuario ? 'true' : 'false'})"
                    >
                        ${usuario.seguido_pelo_usuario ? 'Seguindo' : 'Seguir'}
                    </button>
                ` : '';

                modalContent.innerHTML = `
                    <button class="modal-fechar" onclick="fecharModalProjeto()">X</button>

                    <div class="perfil-container">

                        <div class="perfil-header">
                            ${avatarPerfil}

                            <h2>${usuario.nome}</h2>
                            <p class="perfil-username">@${usuario.username}</p>

                            <div class="perfil-stats">
                                <div class="perfil-stat">
                                    <strong>${usuario.total_projetos}</strong>
                                    <span>Projetos</span>
                                </div>

                                <div class="perfil-stat">
                                    <strong>${usuario.total_seguidores || 0}</strong>
                                    <span>Seguidores</span>
                                </div>

                                <div class="perfil-stat">
                                    <strong>${usuario.total_seguindo || 0}</strong>
                                    <span>Seguindo</span>
                                </div>
                            </div>

                            <p class="perfil-bio">${bioPerfil}</p>

                            ${botaoEditarPerfil}

                            ${botaoSeguirPerfil}

                            ${formularioEdicaoPerfil}

                            <div id="perfil-equipe"></div>
                        </div>

                        <div class="perfil-grid">
                            ${carros.length === 0
                                ? '<p style="color:#666;">Nenhum projeto cadastrado.</p>'
                                : carros.map(c => `
                                    <div class="perfil-card" onclick="abrirProjetoDoPerfil(${c.id}, ${usuario.id})">

                                        ${c.foto_url
                                            ? `<img src="${API_URL}/uploads/${c.foto_url}">`
                                            : `<div class="perfil-sem-foto">SEM FOTO</div>`
                                        }

                                        <div class="perfil-card-info">
                                            <strong>${c.modelo}</strong>
                                            <span>${c.ano}</span>
                                        </div>

                                    </div>
                                `).join('')
                            }
                        </div>

                    </div>
                `;

                modal.style.display = "block";
                modalContent.style.visibility = "visible";

                resetarScrollModalProjeto();

                setTimeout(() => {
                    resetarScrollModalProjeto();
                    modalContent.classList.remove("trocando-conteudo");
                }, 120);

                carregarEquipeDoPerfil(usuarioId);

            } catch (error) {
                console.error(error);
                mostrarMensagem("Erro ao carregar perfil.", "erro");
            }
        }

        async function salvarPerfil(usuarioId) {
            const usuarioLogado = getUsuarioLogado();

            if (!usuarioLogado || String(usuarioLogado.id) !== String(usuarioId)) {
                mostrarMensagem("Você não tem permissão para editar este perfil.", "erro");
                return;
            }

            const avatarArquivoInput = document.getElementById('perfil-avatar-arquivo');
            const avatarAtualInput = document.getElementById('perfil-avatar-atual');
            const bioInput = document.getElementById('perfil-bio');

            let avatarUrlFinal = avatarAtualInput ? avatarAtualInput.value : '';

            try {
                if (avatarArquivoInput && avatarArquivoInput.files.length > 0) {
                    const arquivoAvatar = avatarArquivoInput.files[0];

                    const tamanhoMaximoMB = 3;
                    const tamanhoMaximoBytes = tamanhoMaximoMB * 1024 * 1024;

                    if (arquivoAvatar.size > tamanhoMaximoBytes) {
                        mostrarMensagem(`A imagem deve ter no máximo ${tamanhoMaximoMB}MB.`, "aviso");
                        return;
                    }

                    const tiposPermitidos = ['image/png', 'image/jpeg', 'image/webp'];

                    if (!tiposPermitidos.includes(arquivoAvatar.type)) {
                        mostrarMensagem("Formato não permitido. Use PNG, JPG, JPEG ou WEBP.", "aviso");
                        return;
                    }

                    const formData = new FormData();
                    formData.append('usuario_id', usuarioLogado.id);
                    formData.append('arquivo', arquivoAvatar);

                    const resAvatar = await fetch(`${API_URL}/usuarios/${usuarioId}/avatar`, {
                        method: 'POST',
                        body: formData
                    });

                    const respostaAvatar = await resAvatar.json();

                    if (!resAvatar.ok) {
                        mostrarMensagem(respostaAvatar.erro || "Erro ao enviar avatar.", "erro");
                        return;
                    }

                    avatarUrlFinal = respostaAvatar.avatar_url;
                }

                const res = await fetch(`${API_URL}/usuarios/${usuarioId}`, {
                    method: 'PUT',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        usuario_id: usuarioLogado.id,
                        avatar_url: avatarUrlFinal,
                        bio: bioInput.value.trim()
                    })
                });

                const resposta = await res.json();

                if (res.ok) {
                    localStorage.setItem('usuarioLogado', JSON.stringify({
                        ...usuarioLogado,
                        avatar_url: resposta.avatar_url,
                        bio: resposta.bio
                    }));

                    abrirPerfil(usuarioId);
                } else {
                    mostrarMensagem(resposta.erro || "Erro ao salvar perfil.", "erro");
                }

            } catch (error) {
                console.error("Erro ao salvar perfil:", error);
                mostrarMensagem("Erro de conexão. Veja o console do navegador e o terminal do Flask.", "erro");
            }
        }

        function mostrarEdicaoPerfil() {
            const form = document.getElementById('perfil-edicao');

            if (!form) {
                return;
            }

            const estaAberto = form.style.display === 'block';
            form.style.display = estaAberto ? 'none' : 'block';
        }

        document.addEventListener('change', (e) => {
            if (e.target.id === 'perfil-avatar-arquivo') {
                const nome = document.getElementById('avatar-nome');

                if (!nome) {
                    return;
                }

                nome.textContent = e.target.files.length > 0
                    ? e.target.files[0].name
                    : "Nenhum arquivo";
            }

            if (e.target.id === 'input-foto') {
                const nome = document.getElementById('carro-foto-nome');

                if (!nome) {
                    return;
                }

                nome.textContent = e.target.files.length > 0
                    ? e.target.files[0].name
                    : "Nenhum arquivo";
            }

            if (e.target.id === 'galeria-foto-input') {
                const nome = document.getElementById('galeria-foto-nome');

                if (!nome) {
                    return;
                }

                nome.textContent = e.target.files.length > 0
                    ? e.target.files[0].name
                    : "Nenhum arquivo";
            }

            if (e.target.id === 'input-evolucao-imagem') {
                const nome = document.getElementById('evolucao-imagem-nome');

                if (!nome) {
                    return;
                }

                nome.textContent = e.target.files.length > 0
                    ? e.target.files[0].name
                    : "Nenhum arquivo";
            }
        });

        async function alternarSeguir(usuarioId, jaSegue) {
            const usuarioLogado = getUsuarioLogado();

            if (!usuarioLogado) {
                mostrarMensagem("Você precisa estar logado para seguir usuários.", "aviso");
                return;
            }

            try {
                const res = await fetch(`${API_URL}/usuarios/${usuarioId}/seguir`, {
                    method: jaSegue ? 'DELETE' : 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        usuario_id: usuarioLogado.id
                    })
                });

                const resposta = await res.json();

                if (res.ok) {
                    const novoEstadoSeguindo = !jaSegue;
                    const botaoSeguir = document.querySelector('.btn-seguir-perfil');
                    const perfilStats = document.querySelectorAll('.perfil-stat strong');
                    const seguidoresEl = perfilStats[1];

                    if (botaoSeguir) {
                        botaoSeguir.classList.toggle('seguindo', novoEstadoSeguindo);
                        botaoSeguir.innerText = novoEstadoSeguindo ? 'Seguindo' : 'Seguir';
                        botaoSeguir.setAttribute(
                            'onclick',
                            `alternarSeguir(${usuarioId}, ${novoEstadoSeguindo})`
                        );
                    }

                    if (seguidoresEl) {
                        const totalAtual = parseInt(seguidoresEl.innerText, 10) || 0;
                        const novoTotal = novoEstadoSeguindo
                            ? totalAtual + 1
                            : Math.max(0, totalAtual - 1);

                        seguidoresEl.innerText = novoTotal;
                    }
                } else {
                    mostrarMensagem(resposta.erro || "Erro ao atualizar follow.", "erro");
                }

            } catch (error) {
                console.error(error);
                mostrarMensagem("Erro de conexão.", "erro");
            }
        }

        function abrirProjetoDoPerfil(projetoId, usuarioId) {
            perfilParaReabrirAposProjeto = usuarioId;
            abrirProjetoPorId(projetoId);
        }

        async function abrirProjetoPorId(id) {
            const carro = todosCarros.find(c => String(c.id) === String(id));

            if (carro) {
                abrirModalProjeto(carro);
                return;
            }

            try {
                const res = await fetch(`${API_URL}/carros`);
                const lista = await res.json();

                const encontrado = lista.find(c => String(c.id) === String(id));

                if (encontrado) {
                    abrirModalProjeto(encontrado);
                } else {
                    mostrarMensagem("Projeto não encontrado.", "aviso");
                }
            } catch (error) {
                console.error(error);
                mostrarMensagem("Erro ao abrir projeto.", "erro");
            }
        }

        function abrirComentariosProjeto(carro) {
            abrirModalProjeto(carro);

            setTimeout(() => {
                const comentarios = document.getElementById('comentarios-container');

                if (comentarios) {
                    comentarios.scrollIntoView({ behavior: 'smooth' });
                }
            }, 200);
        }

        function criarParticulas(element) {
            const rect = element.getBoundingClientRect();

            for (let i = 0; i < 6; i++) {
                const p = document.createElement('div');
                p.className = 'like-particle';

                const x = (Math.random() - 0.5) * 60 + 'px';
                const y = (Math.random() - 0.5) * 60 + 'px';

                p.style.left = (rect.left + rect.width / 2) + 'px';
                p.style.top = (rect.top + rect.height / 2) + 'px';

                p.style.setProperty('--x', x);
                p.style.setProperty('--y', y);

                document.body.appendChild(p);

                setTimeout(() => p.remove(), 600);
            }
        }

       async function curtirPeloModal(carroId) {
            await alternarCurtida(carroId);

            await carregarGaragem();

            const atualizado = todosCarros.find(c => String(c.id) === String(carroId));

            if (!atualizado) return;

            const blocoCurtidas = document.querySelector('.comentarios-like');

            if (blocoCurtidas) {
                const total = atualizado.total_curtidas || 0;

                blocoCurtidas.innerHTML = `
                    👍 ${total} ${total === 1 ? 'curtida' : 'curtidas'}
                `;

                // 🔥 FALTA ISSO AQUI
                const curtido = estaCurtido(atualizado.curtido_pelo_usuario);

                blocoCurtidas.classList.toggle('curtido', curtido);
            }
        }

        function estaCurtido(valor) {
            return valor === true || valor === 1 || valor === "1";
        }

        function abrirMeuPerfil() {
            const menu = document.getElementById('usuario-barra');

            if (menu) {
                menu.classList.remove('aberto');
            }

            const usuario = getUsuarioLogado();

            if (!usuario) {
                mostrarMensagem("Faça login para ver seu perfil.", "aviso");
                return;
            }

            abrirPerfil(usuario.id);
        }

        function alternarMenuUsuario(event) {
            if (event) {
                event.stopPropagation();
            }

            const menu = document.getElementById('usuario-barra');
            const dropdown = document.getElementById('usuario-dropdown');

            if (!menu || !dropdown) return;

            const estaAberto = dropdown.classList.contains('aberto');

            if (estaAberto) {
                menu.classList.remove('aberto');
                dropdown.classList.remove('aberto');
                dropdown.style.display = 'none';
            } else {
                menu.classList.add('aberto');
                dropdown.classList.add('aberto');
                dropdown.style.display = 'block';
            }
        }

        function fecharMenuUsuario() {
            const menu = document.getElementById('usuario-barra');
            const dropdown = document.getElementById('usuario-dropdown');

            if (!menu || !dropdown) return;

            menu.classList.remove('aberto');
            dropdown.classList.remove('aberto');
            dropdown.style.display = 'none';
        }

        document.addEventListener('click', function(event) {
            const menu = document.getElementById('usuario-barra');

            if (!menu) return;

            if (!menu.contains(event.target)) {
                fecharMenuUsuario();
            }
        });

        async function carregarEquipeDoPerfil(usuarioId) {
            const container = document.getElementById('perfil-equipe');

            if (!container) return;

            container.innerHTML = '';

            try {
                const resposta = await fetch(`${API_URL}/usuarios/${usuarioId}/clube`);

                if (!resposta.ok) {
                    container.innerHTML = '';
                    return;
                }

                const equipe = await resposta.json();

                if (!equipe) {
                    container.innerHTML = '';
                    return;
                }

                const totalMembros = Array.isArray(equipe.membros)
                    ? equipe.membros.length
                    : (equipe.total_membros || 0);

                container.innerHTML = `
                    <div class="perfil-equipe-badge" onclick="abrirEquipe(${equipe.id})">
                        <div class="perfil-equipe-icone">🏁</div>

                        <div class="perfil-equipe-conteudo">
                            <span class="perfil-equipe-label">Equipe</span>
                            <strong class="perfil-equipe-nome">${textoSeguro(equipe.nome)}</strong>
                            <span class="perfil-equipe-meta-linha">${totalMembros} membro${totalMembros === 1 ? '' : 's'}</span>
                        </div>

                        <div class="perfil-equipe-acao">Ver →</div>
                    </div>
                `;
            } catch (erro) {
                console.error('Erro ao carregar equipe do perfil:', erro);
                container.innerHTML = '';
            }
        }

        configurarInteracoesAuth();
        atualizarTelaUsuario();
