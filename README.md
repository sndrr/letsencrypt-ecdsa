# letsencrypt-ecdsa

Use EC certificates with Let's Encrypt

# Background
Since Let's Encrypt does not support EC certificates from the command line, you have to feed it a CSR that uses EC primes. That CSR can then be fed to certbot.

# Create

Usage:
```
./create.sh -s one.example.org [two.example.org three.example.org ..]
```

What it does:
1. Create a date-prefixed private key + CSR with a prime256v1 curve (adapt the variable `CURVE` to suit your needs).
2. Symlink the private key and CSR to their canonical names ($SITE.key.pem and $SITE.csr.pem)
3. Use the CSR from step 2 to request a Let's Encrypt certificate (with SAN, and with more if multiple sites are given).

# Renew
Usage:
```
./renew.sh -s one.example.org
```

What it does:
1. Test if we can read the fullchain for given site.
2. If it can read the fullchain, it will find out all SANs for the existing certificate
3. Renew the certificate with Let's Encrypt

# Is it any good?
Yes

