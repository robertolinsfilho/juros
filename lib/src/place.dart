/// Caminho de cada tela. O navegador guarda isso no endereço,
/// então voltar e recarregar ficam na tela certa.
int? trySection(String path) {
  return switch (path) {
    '/' || '/painel' => 0,
    '/cobrancas' => 1,
    '/clientes' => 2,
    '/emprestimos' => 3,
    '/caixa' => 4,
    '/relatorios' => 5,
    '/lixeira' => 6,
    '/configuracoes' => 7,
    '/usuarios' => 8,
    '/perfil' => 9,
    '/consultas' => 10,
    _ => null,
  };
}

int sectionForPath(String path) => trySection(path) ?? 0;

String pathForSection(int section) {
  return switch (section) {
    1 => '/cobrancas',
    2 => '/clientes',
    3 => '/emprestimos',
    4 => '/caixa',
    5 => '/relatorios',
    6 => '/lixeira',
    7 => '/configuracoes',
    8 => '/usuarios',
    9 => '/perfil',
    10 => '/consultas',
    _ => '/',
  };
}

bool isAuthPath(String path) => path == '/entrar' || path == '/criar';

bool isConsultaReturn(String? flag) => flag == 'ok' || flag == 'pendente';

/// A volta do Mercado Pago abre em consultas só enquanto o endereço ainda é a raiz.
int sectionForLocation(String path, {String? consulta, bool honorConsulta = true}) {
  if (honorConsulta && (path == '/' || path.isEmpty) && isConsultaReturn(consulta)) return 10;
  return sectionForPath(path);
}
