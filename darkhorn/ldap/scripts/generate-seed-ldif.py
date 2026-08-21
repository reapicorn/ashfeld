#!/usr/bin/env python3
"""
generate-seed-ldif.py
Generates 02-users.ldif and 03-groups.ldif for darkhorn-ldap.

Usage:
    python3 generate-seed-ldif.py [--out <dir>]

Output files are written to ldap/bootstrap/ by default (one level up from this
script), or to the directory specified by --out.
"""

import argparse
import os
import random
import sys

USERS_COUNT  = 150
GROUPS_COUNT = 50

FIRST_NAMES = [
    'James','Mary','John','Patricia','Robert','Jennifer','Michael','Linda','William','Barbara',
    'David','Susan','Richard','Jessica','Joseph','Sarah','Thomas','Karen','Charles','Lisa',
    'Christopher','Nancy','Daniel','Betty','Matthew','Margaret','Anthony','Sandra','Mark','Ashley',
    'Donald','Dorothy','Steven','Kimberly','Paul','Emily','Andrew','Donna','Joshua','Michelle',
    'Kenneth','Carol','Kevin','Amanda','Brian','Melissa','George','Deborah','Timothy','Stephanie',
]

LAST_NAMES = [
    'Smith','Johnson','Williams','Brown','Jones','Garcia','Miller','Davis','Rodriguez','Martinez',
    'Hernandez','Lopez','Gonzalez','Wilson','Anderson','Thomas','Taylor','Moore','Jackson','Martin',
    'Lee','Perez','Thompson','White','Harris','Sanchez','Clark','Ramirez','Lewis','Robinson',
    'Walker','Young','Allen','King','Wright','Scott','Torres','Nguyen','Hill','Flores',
    'Green','Adams','Nelson','Baker','Hall','Rivera','Campbell','Mitchell','Carter','Roberts',
]

DEPARTMENTS = [
    'Engineering','IT','Finance','HR','Marketing','Sales','Legal','Operations',
    'Research','Support','Security','DevOps','Product','Design','Procurement',
]

TITLES = [
    'Engineer','Analyst','Manager','Director','Specialist','Coordinator','Consultant',
    'Administrator','Developer','Architect','Lead','Advisor','Officer','Associate','Executive',
]

GROUP_PREFIXES = [
    'admins','developers','devops','finance','hr','legal','marketing','sales','support',
    'security','readonly','power-users','auditors','managers','analysts','architects',
    'ops','engineering','research','product',
]


def generate_groups():
    groups = []
    used = set()
    while len(groups) < GROUPS_COUNT:
        prefix = random.choice(GROUP_PREFIXES)
        suffix = str(len(groups) + 1).zfill(2)
        name = prefix if prefix not in used else f'{prefix}-{suffix}'
        used.add(name)
        groups.append({'name': name, 'description': f'{name} group'})
    return groups


def generate_users(groups):
    users = []
    used_uids = set()
    for i in range(USERS_COUNT):
        first = random.choice(FIRST_NAMES)
        last  = random.choice(LAST_NAMES)
        uid   = f'{first.lower()}.{last.lower()}'
        if uid in used_uids:
            uid = f'{uid}{i}'
        used_uids.add(uid)

        user_groups = [g['name'] for g in random.sample(groups, random.randint(0, 3))]
        suspended   = random.random() < 0.1
        users.append({
            'uid':        uid,
            'cn':         f'{first} {last}',
            'sn':         last,
            'givenName':  first,
            'mail':       f'{uid}@darkhorn.local',
            'password':   'Passw0rd!',
            'department': random.choice(DEPARTMENTS),
            'title':      random.choice(TITLES),
            'groups':     user_groups,
            'suspended':  suspended,
        })
    return users


def build_users_ldif(users):
    lines = []
    for u in users:
        lines.append(f"dn: uid={u['uid']},ou=People,dc=darkhorn,dc=local")
        lines.append('objectClass: inetOrgPerson')
        lines.append('objectClass: organizationalPerson')
        lines.append('objectClass: person')
        lines.append(f"uid: {u['uid']}")
        lines.append(f"cn: {u['cn']}")
        lines.append(f"sn: {u['sn']}")
        lines.append(f"givenName: {u['givenName']}")
        lines.append(f"mail: {u['mail']}")
        lines.append(f"userPassword: {u['password']}")
        lines.append(f"departmentNumber: {u['department']}")
        lines.append(f"title: {u['title']}")
        if u['suspended']:
            lines.append('description: suspended')
        lines.append('')
    return '\n'.join(lines)


def build_groups_ldif(groups, users):
    member_map = {g['name']: [] for g in groups}
    for u in users:
        for gname in u['groups']:
            if gname in member_map:
                member_map[gname].append(f"uid={u['uid']},ou=People,dc=darkhorn,dc=local")

    lines = []
    for g in groups:
        lines.append(f"dn: cn={g['name']},ou=Groups,dc=darkhorn,dc=local")
        lines.append('objectClass: groupOfNames')
        lines.append(f"cn: {g['name']}")
        lines.append(f"description: {g['description']}")
        members = member_map[g['name']]
        # groupOfNames requires at least one member
        if not members:
            lines.append('member: cn=svc-darkhorn,ou=People,dc=darkhorn,dc=local')
        else:
            for m in members:
                lines.append(f'member: {m}')
        lines.append('')
    return '\n'.join(lines)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out', default=None,
                        help='Directory to write LDIF files (default: ../bootstrap)')
    args = parser.parse_args()

    out_dir = args.out if args.out else \
        os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'bootstrap')

    groups = generate_groups()
    users  = generate_users(groups)

    users_path  = os.path.join(out_dir, '02-users.ldif')
    groups_path = os.path.join(out_dir, '03-groups.ldif')

    with open(users_path, 'w', encoding='utf-8') as f:
        f.write(build_users_ldif(users))

    with open(groups_path, 'w', encoding='utf-8') as f:
        f.write(build_groups_ldif(groups, users))

    print(f'[ldap-seed] {len(users)} users  → bootstrap/02-users.ldif')
    print(f'[ldap-seed] {len(groups)} groups → bootstrap/03-groups.ldif')


if __name__ == '__main__':
    main()
