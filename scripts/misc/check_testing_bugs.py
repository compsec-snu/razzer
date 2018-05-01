#!/usr/bin/python

import sys

testing_bugs = [
    ('drivers/tty/n_hdlc.c:440', 'drivers/tty/n_hdlc.c:216'),
    ('net/packet/af_packet.c:3660', 'net/packet/af_packet.c:4229'),
    ('net/packet/af_packet.c:1653', 'net/packet/af_packet.c:1710'),
    ('net/ipv4/raw.c:640', 'net/ipv4/ip_sockglue.c:748'), ('net/sctp/associola.c:1088', 'net/sctp/socket.c:7423'),
    ('net/packet/af_packet.c:1645', 'net/packet/af_packet.c:367')
    ]

def check_testing_bugs(line):
    toks = line.strip().split()
    for testing_bug in testing_bugs:
        if testing_bug[0] in toks[0] and testing_bug[1] in toks[1]:
            return testing_bug
        elif testing_bug[1] in toks[0] and testing_bug[0] in toks[1]:
            return testing_bug
    return None


if __name__ == '__main__':
    check = {}
    for testing_bug in testing_bugs:
        check[testing_bug] = False

    with open(sys.argv[1]) as f:
        for line in f:
            check[check_testing_bugs(line)] = True

        for testing_bug in testing_bugs:
            if not check[testing_bug]:
                print '\t[WARN] Testing bug', testing_bug, 'not found'
            else:
                print '\t[OK] Testing bug', testing_bug, 'found'
