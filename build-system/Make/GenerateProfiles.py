import json
import os
import sys
import shutil
import tempfile
import plistlib
import argparse
import subprocess
import base64

from BuildEnvironment import run_executable_with_output, check_run_system


def setup_temp_keychain(p12_path, p12_password=''):
    """Use existing temp.keychain or create a temporary keychain."""
    existing = run_executable_with_output('security', arguments=['list-keychains', '-d', 'user'])
    if 'temp.keychain' in existing:
        run_executable_with_output('security', arguments=['unlock-keychain', '-p', 'secret', 'temp.keychain'], check_result=False)
        return 'temp.keychain'

    keychain_name = 'generate-profiles-temp.keychain'
    keychain_password = 'temp123'

    # Delete if exists
    run_executable_with_output('security', arguments=['delete-keychain', keychain_name], check_result=False)

    # Create keychain
    run_executable_with_output('security', arguments=[
        'create-keychain', '-p', keychain_password, keychain_name
    ], check_result=True)

    # Add to search list
    run_executable_with_output('security', arguments=[
        'list-keychains', '-d', 'user', '-s', keychain_name, existing.replace('"', '')
    ], check_result=True)

    # Unlock and set settings
    run_executable_with_output('security', arguments=['set-keychain-settings', keychain_name])
    run_executable_with_output('security', arguments=[
        'unlock-keychain', '-p', keychain_password, keychain_name
    ])

    # Import p12
    run_executable_with_output('security', arguments=[
        'import', p12_path, '-k', keychain_name, '-P', p12_password,
        '-T', '/usr/bin/codesign', '-T', '/usr/bin/security'
    ], check_result=True)

    # Set partition list for access
    run_executable_with_output('security', arguments=[
        'set-key-partition-list', '-S', 'apple-tool:,apple:', '-k', keychain_password, keychain_name
    ], check_result=True)

    return keychain_name


def cleanup_temp_keychain(keychain_name):
    """Remove the temporary keychain if not main temp.keychain."""
    if keychain_name != 'temp.keychain':
        run_executable_with_output('security', arguments=['delete-keychain', keychain_name], check_result=False)


def get_signing_identity_from_p12(p12_path, p12_password=''):
    """Extract the common name (signing identity) from the p12 certificate."""
    try:
        proc = subprocess.Popen(
            ['openssl', 'pkcs12', '-in', p12_path, '-passin', 'pass:' + p12_password, '-nokeys'],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE
        )
        cert_pem, _ = proc.communicate()
        if not cert_pem:
            proc = subprocess.Popen(
                ['openssl', 'pkcs12', '-in', p12_path, '-passin', 'pass:' + p12_password, '-nokeys', '-legacy'],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE
            )
            cert_pem, _ = proc.communicate()

        if cert_pem:
            proc2 = subprocess.Popen(
                ['openssl', 'x509', '-noout', '-subject', '-nameopt', 'oneline,-esc_msb'],
                stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE
            )
            subject, _ = proc2.communicate(cert_pem)
            subject = subject.decode('utf-8').strip()

            if 'CN = ' in subject:
                cn = subject.split('CN = ')[-1].split(',')[0].strip()
                return cn
    except Exception:
        pass

    return 'Apple Distribution: Telegram FZ-LLC (C67CF9S4VU)'


def get_certificate_base64_from_p12(p12_path, p12_password='', certs_path=None):
    """Extract the certificate as base64 from Public.cer or p12 file."""
    if certs_path:
        public_cer = os.path.join(certs_path, 'Public.cer')
        if os.path.exists(public_cer):
            with open(public_cer, 'rb') as f:
                return base64.b64encode(f.read()).decode('utf-8')

    try:
        proc = subprocess.Popen(
            ['openssl', 'pkcs12', '-in', p12_path, '-passin', 'pass:' + p12_password, '-nokeys'],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE
        )
        cert_pem, _ = proc.communicate()
        if not cert_pem:
            proc = subprocess.Popen(
                ['openssl', 'pkcs12', '-in', p12_path, '-passin', 'pass:' + p12_password, '-nokeys', '-legacy'],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE
            )
            cert_pem, _ = proc.communicate()

        proc2 = subprocess.Popen(
            ['openssl', 'x509', '-outform', 'DER'],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE
        )
        cert_der, _ = proc2.communicate(cert_pem)
        if cert_der:
            return base64.b64encode(cert_der).decode('utf-8')
    except Exception:
        pass

    return ''


def process_provisioning_profile(source, destination, certificate_data, signing_identity, keychain_name, bundle_id=None):
    parsed_plist = run_executable_with_output('security', arguments=['cms', '-D', '-i', source], check_result=True)
    if bundle_id:
        parsed_plist = parsed_plist.replace('ph.telegra.Telegraph', bundle_id)
    parsed_plist_file = tempfile.mktemp()
    with open(parsed_plist_file, 'w+') as file:
        file.write(parsed_plist)

    # Remove all existing developer certificates
    while True:
        result = run_executable_with_output('plutil', arguments=['-remove', 'DeveloperCertificates.0', parsed_plist_file], check_result=False)
        if result is None or 'Could not' in str(result) or result == '':
            # Check if the removal actually failed by trying to extract
            check = run_executable_with_output('plutil', arguments=['-extract', 'DeveloperCertificates.0', 'raw', parsed_plist_file], check_result=False)
            if check is None or 'Could not' in str(check):
                break

    # Insert the new certificate
    run_executable_with_output('plutil', arguments=['-insert', 'DeveloperCertificates.0', '-data', certificate_data, parsed_plist_file])

    # Remove the DER-Encoded-Profile (signature)
    run_executable_with_output('plutil', arguments=['-remove', 'DER-Encoded-Profile', parsed_plist_file])

    # Sign with the certificate from the temporary keychain
    run_executable_with_output('security', arguments=[
        'cms', '-S', '-k', keychain_name, '-N', signing_identity, '-i', parsed_plist_file, '-o', destination
    ], check_result=True)

    os.unlink(parsed_plist_file)


def generate_provisioning_profiles(source_path, destination_path, certs_path, bundle_id=None):
    p12_path = os.path.join(certs_path, 'SelfSigned.p12')

    if not os.path.exists(p12_path):
        print('{} does not exist'.format(p12_path))
        sys.exit(1)

    if not os.path.exists(destination_path):
        print('{} does not exist'.format(destination_path))
        sys.exit(1)

    p12_password = ''
    certificate_data = get_certificate_base64_from_p12(p12_path, p12_password, certs_path=certs_path)
    signing_identity = get_signing_identity_from_p12(p12_path, p12_password)

    print('Using signing identity: {}'.format(signing_identity))

    keychain_name = setup_temp_keychain(p12_path, p12_password)

    try:
        for file_name in os.listdir(source_path):
            if file_name.endswith('.mobileprovision'):
                print('Processing {}'.format(file_name))
                process_provisioning_profile(
                    source=os.path.join(source_path, file_name),
                    destination=os.path.join(destination_path, file_name),
                    certificate_data=certificate_data,
                    signing_identity=signing_identity,
                    keychain_name=keychain_name,
                    bundle_id=bundle_id
                )
        print('Done. Generated {} profiles.'.format(
            len([f for f in os.listdir(destination_path) if f.endswith('.mobileprovision')])
        ))
    finally:
        cleanup_temp_keychain(keychain_name)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', required=True)
    parser.add_argument('--destination', required=True)
    parser.add_argument('--certs', required=True)
    parser.add_argument('--bundleId', required=False, default=None)
    args = parser.parse_args()

    generate_provisioning_profiles(
        source_path=args.source,
        destination_path=args.destination,
        certs_path=args.certs,
        bundle_id=args.bundleId
    )
