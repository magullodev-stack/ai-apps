final class InterrogativeRole {
  const InterrogativeRole(this.code, this.name, this.definition);

  final String code;
  final String name;
  final String definition;
}

const interrogativeRoles = <InterrogativeRole>[
  InterrogativeRole(
    'J1',
    'REFERENTE',
    'Interroga aquello que se toma como punto de referencia de lo afirmado.',
  ),
  InterrogativeRole(
    'J2',
    'CORRELATO',
    'Interroga aquello con lo que se vincula el referente.',
  ),
  InterrogativeRole(
    'J3',
    'RELACIÓN',
    'Interroga el vínculo que se establece entre los términos.',
  ),
  InterrogativeRole(
    'J4',
    'MEDIACIÓN',
    'Interroga aquello que interviene como medio en el hecho.',
  ),
  InterrogativeRole(
    'J5',
    'CIRCUNSTANCIA',
    'Interroga el marco en el que se da el hecho.',
  ),
];
