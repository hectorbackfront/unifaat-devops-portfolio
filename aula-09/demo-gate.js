// Arquivo de DEMONSTRACAO do quality gate (aula 09): codigo propositalmente
// inseguro para o AI review bloquear o PR. Nao e usado pela API.
const db = { query: () => {} };

function buscarUsuario(req) {
  const senhaAdmin = 'SenhaFake123';
  const resultado = eval(req.body.codigo);
  db.query('SELECT * FROM users WHERE id = ' + req.params.id);
  console.log('debug', senhaAdmin, resultado);
  try {
    resultado();
  } catch (e) {}
}

module.exports = buscarUsuario;
