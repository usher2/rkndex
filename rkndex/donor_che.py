#!/usr/bin/env python3
#
# Fetching data from Che donor.
#

import functools
import logging
import os
import zipfile

import requests

from rkndex.util import file_sha256
from rkndex.const import DUMP_ZIP, DUMP_XML, DUMP_SIG, GITAR_USER_AGENT, LAST_MODIFIED_EPOCH, HTTP_TIMEOUT

class DonorChe(object):
    name = 'che'
    def __init__(self, sqlite_db, file_url):
        self.db = sqlite_db
        self.create_table()
        self.file_url = file_url 
        self.s = requests.Session()
        self.s.headers.update({'User-Agent': GITAR_USER_AGENT})
        it = self.db.execute('SELECT etag, last_modified FROM che LIMIT 1')
        self.etag, self.last_modified = next(it)

    def create_table(self):
        self.db.execute('''CREATE TABLE IF NOT EXISTS che (
            etag            TEXT NOT NULL,
            last_modified   TEXT NOT NULL)''')
        if next(self.db.execute('SELECT 1 FROM che LIMIT 1'), None) is None:
            self.db.execute('INSERT INTO che VALUES (?, ?)',
                ('"{}"'.format(os.urandom(16).hex()), LAST_MODIFIED_EPOCH))
        # NB: pragma_table_info() needs sqlite 3.16.0 (2017-01-02)
        if next(self.db.execute("SELECT 1 FROM pragma_table_info('che') WHERE name = 'xml_sha256'"), None) is None:
            self.db.execute('ALTER TABLE che ADD COLUMN xml_sha256 BLOB')

    def max_update_time(self):
        return next(self.db.execute('SELECT COALESCE(MAX(update_time), 0) FROM che JOIN log USING (xml_sha256)'))[0]

    def list_handles(self, limit):
        assert limit >= 1
        r = self.s.get(self.file_url, stream=True, headers={
            'If-None-Match': self.etag,
            'If-Modified-Since': self.last_modified,
        }, timeout=HTTP_TIMEOUT)
        r.raise_for_status()
        if r.status_code == requests.codes.ok:
            return [r]
        else: # probably, not_modified
            r.close()
            return []

    # FIXME: if something fails between etag update and git commit then the file may be lost.
    def fetch_xml_and_sig(self, tmpdir, r):
        zip_path = os.path.join(tmpdir, DUMP_ZIP)
        with open(zip_path, 'wb') as fd:
            for blob in iter(functools.partial(r.raw.read, 65536), b''):
                fd.write(blob)
        logging.info('%s: got %s, %d bytes, content-length: %s, last-modified: %s, etag: %s',
                self.name, DUMP_ZIP, os.path.getsize(zip_path), r.headers.get('content-length', '?'),
                r.headers.get('last-modified', '?'), r.headers.get('etag', '?'))
        self.etag = r.headers['etag']
        self.last_modified = r.headers['last-modified']
        self.db.execute('BEGIN EXCLUSIVE TRANSACTION')
        with self.db:
            self.db.execute('UPDATE che SET etag = ?, last_modified = ?, xml_sha256 = NULL',
                (self.etag, self.last_modified))
        with zipfile.ZipFile(zip_path, 'r') as zfd:
            zfd.extract(DUMP_SIG, path=tmpdir)
            zfd.extract(DUMP_XML, path=tmpdir)
            xml_binsha256 = file_sha256(os.path.join(tmpdir, DUMP_XML)) # calculated twice...
        self.db.execute('BEGIN EXCLUSIVE TRANSACTION')
        with self.db:
            self.db.execute('UPDATE che SET xml_sha256 = ?', (xml_binsha256,))
        return xml_binsha256

    @staticmethod
    def sanity_cb(handle, xmlmeta, sigmeta, ut, utu):
        pass
