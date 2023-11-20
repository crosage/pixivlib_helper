import json
import os

from django.shortcuts import render
from rest_framework.response import Response
from rest_framework.decorators import api_view
from rest_framework.views import APIView

from pixiv_model.models import PixivToken
from pixiv_model.views import get_refresh_token, get_access_token
from response.models import MyResponse
from argparse import ArgumentParser
from base64 import urlsafe_b64encode
from hashlib import sha256
from pprint import pprint
from secrets import token_urlsafe
from sys import exit
from urllib.parse import urlencode
from webbrowser import open as open_url
import requests

# Latest app version can be found using GET /v1/application-info/android
USER_AGENT = "PixivAndroidApp/5.0.234 (Android 11; Pixel 5)"
REDIRECT_URI = "https://app-api.pixiv.net/web/v1/users/auth/pixiv/callback"
LOGIN_URL = "https://app-api.pixiv.net/web/v1/login"
AUTH_TOKEN_URL = "https://oauth.secure.pixiv.net/auth/token"
CLIENT_ID = "MOBrBDS8blbauoSck0ZfDbtuzpyT"
CLIENT_SECRET = "lsACyCD94FhDUtGTXi3QzcFE2uU1hqtDaKeqrdwj"

def s256(data):
    """S256 transformation method."""

    return urlsafe_b64encode(sha256(data).digest()).rstrip(b"=").decode("ascii")

def oauth_pkce(transform):
    """Proof Key for Code Exchange by OAuth Public Clients (RFC7636)."""

    code_verifier = token_urlsafe(32)
    code_challenge = transform(code_verifier.encode("ascii"))

    return code_verifier, code_challenge

def print_auth_token_response(response):
    data = response.json()

    try:
        access_token = data["access_token"]
        refresh_token = data["refresh_token"]
    except KeyError:
        print("error:")
        pprint(data)
        exit(1)

    print("access_token:", access_token)
    print("refresh_token:", refresh_token)
    print("expires_in:", data.get("expires_in", 0))

def login():
    code_verifier, code_challenge = oauth_pkce(s256)
    login_params = {
        "code_challenge": code_challenge,
        "code_challenge_method": "S256",
        "client": "pixiv-android",
    }

    open_url(f"{LOGIN_URL}?{urlencode(login_params)}")

    try:
        code = input("code: ").strip()
    except (EOFError, KeyboardInterrupt):
        return

    response = requests.post(
        AUTH_TOKEN_URL,
        data={
            "client_id": CLIENT_ID,
            "client_secret": CLIENT_SECRET,
            "code": code,
            "code_verifier": code_verifier,
            "grant_type": "authorization_code",
            "include_policy": "true",
            "redirect_uri": REDIRECT_URI,
        },
        headers={"User-Agent": USER_AGENT},
        proxies={
            "http": "http://127.0.0.1:7890",
            "https": "http://127.0.0.1:7890",
        }
    )

    print_auth_token_response(response)

def refresh(refresh_token):
    response = requests.post(
        AUTH_TOKEN_URL,
        data={
            "client_id": CLIENT_ID,
            "client_secret": CLIENT_SECRET,
            "grant_type": "refresh_token",
            "include_policy": "true",
            "refresh_token": refresh_token,
        },
        headers={"User-Agent": USER_AGENT},
        proxies={
            "http": "http://127.0.0.1:7890",
            "https": "http://127.0.0.1:7890",
        }
    )
    print_auth_token_response(response)

def main():
    parser = ArgumentParser()
    subparsers = parser.add_subparsers()
    parser.set_defaults(func=lambda _: parser.print_usage())
    login_parser = subparsers.add_parser("login")
    login_parser.set_defaults(func=lambda _: login())
    refresh_parser = subparsers.add_parser("refresh")
    refresh_parser.add_argument("refresh_token")
    refresh_parser.set_defaults(func=lambda ns: refresh(ns.refresh_token))
    args = parser.parse_args()
    args.func(args)

class getRefreshToken(APIView):
    def get(self,request):
        response=MyResponse()
        try:
            login()
            return response.success()
        except Exception as e:
            return response.error(e)
class refreshToken(APIView):
    def get(self,request,refresh_token):
        response=MyResponse()
        try:
            refresh(refresh_token)
            return response.success()
        except Exception as e:
            return response.error(e)

class TokenManagementView(APIView):
    def get(self,request):
        response=MyResponse()
        try:
            refresh=get_refresh_token()
            access=get_access_token()
            response.put({"refresh":refresh})
            response.put({"access": access})
            return response.success()
        except Exception as e:
            return response.error(e)

    def post(self, request):
        response = MyResponse()
        try:
            map=json.loads(request.body)
            refresh_token=map.get("refresh")
            access_token=map.get("access")
            instance,create=PixivToken.objects.get_or_create(id=1)
            if create:
                instance.refresh_token=""
                instance.access_token=""
            instance.updateRefreshToken(refresh_token)
            instance.updateAccessToken(access_token)
            return response.success()
        except Exception as e:
            return response.error(e)

    def put(self, request):
        response = MyResponse()
        # try:
        #     # 更新操作
        #     token_id = request.data.get('token_id')
        #     token_model = TokenCookieModel.objects.get(pk=token_id)
        #     token_model.token = get_refresh_token()
        #     token_model.cookie = get_access_token()
        #     token_model.save()
        #     serialized_token = TokenCookieModelSerializer(token_model)
        #     return response.put(serialized_token.data)
        # except Exception as e:
        #     return response.error(e)

    def delete(self, request):
        response = MyResponse()
        # try:
        #     # 删除操作
        #     token_id = request.data.get('token_id')
        #     token_model = TokenCookieModel.objects.get(pk=token_id)
        #     token_model.delete()
        #     return response.success("Token deleted successfully.")
        # except Exception as e:
        #     return response.error(e)


class deleteMulti(APIView):
    def post(self,request):
        response=MyResponse()
        try:
            nowPath=os.getcwd()

            return response.success()
        except Exception as e:
            return response.error(e)

