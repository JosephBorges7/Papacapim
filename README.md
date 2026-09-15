# 🐦 Papacapim

**Papacapim** é um aplicativo mobile de rede social desenvolvido em **Flutter** e **Dart**, focado em simplicidade, design lúdico e interações dinâmicas. O aplicativo foi projetado para demonstrar uma arquitetura de gerenciamento de estados utilizando **Provider**, uma paleta de cores orgânica e moderna (com tons pastéis e roxo marcante) e uma experiência nativa de navegação.

## ✨ Funcionalidades Principais
- **Autenticação Simulada:** Telas de Login e Cadastro (sem necessidade de banco de dados real inicial).
- **Feed de Publicações:** Abas separadas para "Geral" (todos os posts da rede) e "Seguindo".
- **Interações de Rede Social:** Curtir posts, seguir/deixar de seguir usuários e apagar próprios posts.
- **Busca Integrada:** Pesquisa em tempo real de usuários e posts, dividida em abas interativas.
- **Gerenciamento de Perfil:** Visualização de posts próprios e contadores dinâmicos de seguidores e postagens.
- **Design System Centralizado:** Estilos, botões, cards e tipografia gerenciados de forma unificada (`AppTheme`).

## 🛠️ Tecnologias Utilizadas
- **Framework:** [Flutter](https://flutter.dev/) (SDK 3.0+)
- **Linguagem:** Dart
- **Gerenciamento de Estado:** Provider
- **Fontes e Tipografia:** Google Fonts (Baloo 2 e Nunito)
- **Dados:** Mock data em memória para rápida prototipação.

## 🚀 Como Executar o Projeto

1. Certifique-se de que o **Flutter SDK** está instalado em sua máquina.
2. Clone este repositório:
   ```bash
   git clone https://github.com/JosephBorges7/Papacapim.git
   ```
3. Acesse o diretório do projeto:
   ```bash
   cd Papacapim/papacapim
   ```
4. Instale as dependências:
   ```bash
   flutter pub get
   ```
5. Rode o aplicativo (escolha um emulador, dispositivo físico ou web):
   ```bash
   flutter run -d chrome --web-browser-flag "--disable-web-security"
   ```

---
*Desenvolvido com Flutter para oferecer uma experiência nativa agradável e divertida!*
