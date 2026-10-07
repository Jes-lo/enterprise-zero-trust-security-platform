# Organization Model

## Purpose

The project uses a completely synthetic enterprise organization identified
internally as `ZT-LAB`.

`ZT-LAB` is a laboratory identifier and is not intended to represent a
real company, brand, customer, employer, or commercial product.

No real employee, customer, employer, or production information is used.

## Departments

The synthetic organization contains the following functional areas:

| Code | Department |
|---|---|
| EXEC | Executive |
| FIN | Finance |
| HR | Human Resources |
| SALES | Sales |
| ENG | Engineering |
| ITOPS | IT Operations |
| SEC | Security |

These departments create different security requirements without relying
on information from any real organization.

## Identity personas

The environment models multiple identity types because a Zero Trust design
must not treat all identities as equivalent.

### Employee

Normal workforce identity used for productivity services.

### Developer

Engineering workforce identity requiring access to development resources
without receiving broad tenant administration rights.

### IT Operator

Operational identity with delegated administrative responsibilities.

### Security Engineer

Identity used for security administration, investigation, and security
engineering activities.

### Privileged Administrator

Dedicated administrative identity that is separate from the administrator's
normal productivity identity.

### Executive

High-value workforce identity subject to stronger protection because of
business impact and targeting risk.

### Contractor

External workforce identity with explicit scope and time-bound access.

### Guest

External identity used for controlled collaboration.

### Workload

Non-human identity representing an application, service principal, or
automation workload.

### Emergency Administrator

Highly restricted identity reserved for emergency recovery when normal
administrative access paths are unavailable.

## Privilege classes

The project uses four original privilege classes.

| Class | Name | Purpose |
|---|---|---|
| PC0 | Emergency | Recovery-only administrative access |
| PC1 | Privileged | High-impact tenant administration |
| PC2 | Operational | Constrained delegated administration |
| PC3 | Standard | Normal workforce and collaboration access |

Privilege class is independent from department.

A Security employee, for example, can have:

- a PC3 productivity identity; and
- a separate PC1 administrative identity.

This separation prevents normal productivity activity from automatically
inheriting high-impact administrative privileges.

## Data model

The machine-readable organization definition is stored in:

`configs/organization-model.json`

Later automation must consume the model instead of embedding department or
persona definitions independently in scripts.

## Laboratory constraints

The organization model must contain only:

- Synthetic users
- Synthetic groups
- Synthetic departments
- Test devices
- Laboratory applications
- Laboratory security events

Production information is outside the project boundary.
