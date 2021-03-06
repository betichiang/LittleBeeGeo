# -*- coding: utf-8 -*-

from app.constants import *
import os
import random
import math
import base64
import time
import ujson as json
import pytz
import hashlib
from pytz import timezone
from calendar import timegm
from datetime import datetime
from datetime import timedelta
import grequests
import uuid as _uuid

from app import cfg

SPACER_GIF_BYTES = base64.b64decode("R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7")

def db_find(cf_name, key = None, fields={'_id': False}):
    result = []
    try:
        if key is None:
            result = cfg.config.get(cf_name).find(fields=fields)
        else:
            result = cfg.config.get(cf_name).find(key, fields=fields)
    except:
        cfg.logger.exception('unable to db_find: cf_name: %s key: %s', cf_name, key)
        result = None
        
    if result is None:
        result = []
    return list(result)


def db_find_it(cf_name, key = None, fields={'_id': False}):
    result = None
    try:
        if key is None:
            result = cfg.config.get(cf_name).find(fields=fields)
        else:
            result = cfg.config.get(cf_name).find(key, fields=fields)
    except:
        cfg.logger.exception('unable to db_find: cf_name: %s key: %s', cf_name, key)
        result = None
        
    return result


def db_find_one(cf_name, key, fields={'_id': False}):
    try:
        result = cfg.config.get(cf_name).find_one(key, fields=fields)
    except:
        cfg.logger.exception('unable to db_find_one: cf_name: %s key: %s', cf_name, key)
        result = None

    if result is None:
        result = {}

    return dict(result)


def db_update(cf_name, key, val, upsert=True):
    if not key or not val:
        #cfg.logger.exception('not key or val: key: %s val: %s', key, val)
        return

    #cfg.logger.debug('cf_name: %s key: %s val: %s', cf_name, key, val)
    result = {}
    try:
        result = cfg.config.get(cf_name).update(key, {'$set':val}, upsert=upsert, w=1)
    except Exception as e:
        cfg.logger.warning('unable to db_update: cf_name: %s key: %s val: %s e: %s', cf_name, key, val, e)
    return result


def db_insert(cf_name, val):
    error_code = S_OK
    cfg.logger.debug('cf_name: %s val: %s', cf_name, val)
    if not val:
        cfg.logger.error('not val: val: %s', val)
        return

    result = cfg.config.get(cf_name).insert(val)

    return result


def db_insert_if_not_exist(cf_name, key, val):
    if not key or not val:
        cfg.logger.exception('not key or val: key: %s val: %s', key, val)
        return

    cfg.logger.debug('cf_name: %s key: %s val: %s', cf_name, key, val)
    result = cfg.config.get(cf_name).find_and_modify(key, {'$setOnInsert':val}, upsert=True, new=True)
    #cfg.logger.debug('after update: result: %s', result)
    return result


def json_dumps(json_struct, default_val=''):
    result = default_val
    try:
        result = json.dumps(json_struct)
    except:
        cfg.logger.exception('unable to json_dumps: json_struct: %s', json_struct)

    return result


def json_loads(json_str, default_val={}):
    result = default_val
    try:
        result = json.loads(json_str)
    except:
        cfg.logger.exception('unable to json_loads: json_str: %s', json_str)
        result = default_val

    return result


def date_today():
    today = datetime.today()
    return datetime_to_date(today)


def date_tomorrow():
    today = datetime.today()
    the_timedelta = timedelta(days=1)
    tomorrow = today + the_timedelta
    return datetime_to_date(tomorrow)


def datetime_to_date(the_datetime):
    result = the_datetime.strftime("%Y%m%d")
    return result


def datetime_to_date_str(the_datetime):
    result = the_datetime.strftime("%Y-%m-%d")
    return result


def datetime_to_timestamp(the_datetime):
    the_datetime = the_datetime.replace(tzinfo=timezone('Asia/Taipei'))
    the_timestamp = timegm(the_datetime.utctimetuple())
    return the_timestamp


def date_to_timestamp(the_date):
    the_datetime = datetime.strptime(the_date, "%Y%m%d")
    the_datetime = the_datetime.replace(tzinfo = timezone('Asia/Taipei'))
    the_timestamp = _int(timegm(the_datetime.utctimetuple()))
    return the_timestamp


def timestamp_to_date(the_timestamp):
    the_datetime = timestamp_to_datetime(the_timestamp)
    return datetime_to_date(the_datetime)


def timestamp_to_datetime(the_timestamp, the_timezone=None):
    the_datetime = datetime.utcfromtimestamp(_float(the_timestamp))
    the_datetime = the_datetime.replace(tzinfo=pytz.utc)
    if the_timezone:
        the_datetime = the_datetime.astimezone(timezone(the_timezone))
    return the_datetime


def timestamp_to_date_str(the_timestamp, the_timezone=None):
    the_datetime = timestamp_to_datetime(the_timestamp, the_timezone=the_timezone)
    cfg.logger.debug('the_timestamp: %s the_timezone: %s the_datetime: %s', the_timestamp, the_timezone, the_datetime)
    return datetime_to_date_str(the_datetime)


def _float(the_val, default_val=0):
    result = default_val
    try:
        result = float(the_val)
    except:
        cfg.logger.exception('unable to _float: the_val: %s default_val: %s', the_val, default_val)
        
    return result


def _int(the_val, default_val=0):
    result = default_val
    try:
        result = int(the_val)
    except:
        cfg.logger.exception('unable to _int: the_val: %s default_val: %s', the_val, default_val)
        
    return result


def init_cache(cache, cache_name):
    if cache_name not in cache:
        cache[cache_name] = get_cache(cache_name)


def save_cache(key, cache):
    db_update('cacheDB', {'cache_key':key}, {'cache_val':json_dumps(cache)})


def get_cache(key):
    result_db = db_find_one('cacheDB', {'cache_key':key})
    result_db = {} if not result_db else result_db
    return json_loads(result_db.get('cache_val', '{}'), result_db.get('cache_val', {}))


def http_multipost(the_url_data):
    the_urls = the_url_data.keys()
    rs = (grequests.post(the_url, data=the_url_data[the_url], timeout=5) for the_url in the_urls)
    result_map = grequests.map(rs)

    try:
        result_map_text = [_grequest_get_text(each_result_map) for each_result_map in result_map]
        result = {the_url: result_map_text[idx] for (idx, the_url) in enumerate(the_urls)}
    except:
        cfg.logger.exception('the_url_data: %s', the_url_data)
        result = {}
    return result


def http_multiget(the_urls):
    rs = (grequests.get(u, timeout=5) for u in the_urls)
    result_map = grequests.map(rs)
    try:
        result_map_text = [_grequest_get_text(each_result_map) for each_result_map in result_map]
        result = {the_url: result_map_text[idx] for (idx, the_url) in enumerate(the_urls)}
    except:
        cfg.logger.exception('the_urls: %s', the_urls)
        result = {}

    return result


def _grequest_get_text(result):
    if result is None:
        return ''
    if not hasattr(result, 'text'):
        return ''
    return result.text


def big5_to_utf8(text_big5):
    str_utf8 = unicode(text_big5, 'big5', 'ignore')
    return str_utf8


def utf8_to_big5(text_utf8):
    str_big5 = text_utf8.encode('big5')
    return str_big5


def get_timestamp():
    return int(time.time())


def get_milli_timestamp():
    return int(time.time() * 1000)


def uuid():
    return str(_uuid.uuid4())


def makedirs(dir_name):
    if os.path.isdir(dir_name):
        return

    try:
        os.makedirs(dir_name)
        cfg.logger.debug('mkdirs: dir_name: %s', dir_name)
    except Exception as e:
        cfg.logger.error('unable to makedirs: dir_name: %s e: %s', dir_name, e)


def empty_img():
    return SPACER_GIF_BYTES
