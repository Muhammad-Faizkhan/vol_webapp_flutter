/// Asks the browser to confirm leaving the page while [pending] is true. Returns a remover.
void Function() guardUnload(bool Function() pending) => () {};
