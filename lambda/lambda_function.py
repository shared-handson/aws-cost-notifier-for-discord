import json
import boto3
from datetime import timedelta, date
from discord import Webhook, Embed, HTTPException
import logging
from typing import Dict, Any, Optional
import aiohttp
import asyncio
import re
import os
import math

# ログ設定
logger = logging.getLogger()
log_level = os.environ.get("LOG_LEVEL", "ERROR").upper()
logger.setLevel(getattr(logging, log_level, logging.ERROR))

# 汎用AWSアバターの値
AWS_AVATAR_URL = "https://shared-handson.github.io/icons-factory/aws/Cloud-logo.png"
AWS_USERNAME = "AWS Notifier"

# Webhook設定のデフォルト値
# EventBridgeから渡されるオブジェクトの方が優先
WEBHOOK_AVATAR_URL = AWS_AVATAR_URL
WEBHOOK_USERNAME = AWS_USERNAME


def get_config_from_event(event: Dict[str, Any]) -> Dict[str, Any]:
    """
    EventBridgeイベントからWebhook設定値を取得する

    Args:
        event: Lambda関数に渡されるEventBridgeイベントデータ

    Returns:
        dict: Webhook設定値の辞書
            - webhook_url (str): Discord Webhook URL
            - webhook_username (str): Discordに表示されるユーザー名
            - webhook_avatar_url (str): Discordに表示されるアバター画像URL

    Raises:
        ValueError: 必須設定が不足している場合、またはWebhook URLが無効な形式の場合
    """
    config = {}

    # EventBridgeからの設定値を取得
    detail = event.get("detail", {}) if isinstance(event.get("detail"), dict) else {}

    # Webhook設定
    config["webhook_url"] = detail.get("webhookUrl")
    config["webhook_username"] = detail.get("webhookUsername", WEBHOOK_USERNAME)
    config["webhook_avatar_url"] = detail.get("webhookAvatarUrl", WEBHOOK_AVATAR_URL)

    # 必須項目のNullチェック
    if not config["webhook_url"]:
        raise ValueError(
            "Not defined Webhook URL (EventBridge EventsKey is detail.webhookUrl）"
        )

    # URLのバリデーションチェック
    webhook_pattern = r"https://discord\.com/api/webhooks/\d+/[\w-]+"
    if not re.match(webhook_pattern, config["webhook_url"]):
        raise ValueError(f"Invalid value for webhook_url: {config['webhook_url']}")

    logger.info(
        f"Retrieved config values: webhookAvatarUrl={config['webhook_avatar_url']}, webhookUsername={config['webhook_username']}"
    )
    return config


def get_cost(event: Dict[str, Any]) -> Dict[str, Any]:
    """
    指定された期間のAWS利用料金を取得する

    Args:
        event: Lambda関数に渡されるEventBridgeイベントデータ

    Returns:
        cost: コスト情報の辞書
            - budget (float): 月次予算金額（USD）
            - daily: 日次集計
                - PeriodDays (int): コスト取得期間（日数）
                - end (str): 取得期間の終了日（YYYY-MM-DD形式）
                - start (str): 取得期間の開始日（YYYY-MM-DD形式）
                - total (float): 合計コスト（USD）
            - monthly_this: 当月の月次集計
                - PeriodDays (int): コスト取得期間（日数）
                - end (str): 取得期間の終了日（YYYY-MM-DD形式）
                - start (str): 取得期間の開始日（YYYY-MM-DD形式）
                - total (float): 当月の月次集計の合計コスト（USD）
            - monthly_last: 先月の月次集計
                - PeriodDays (int): コスト取得期間（日数）
                - end (str): 取得期間の終了日（YYYY-MM-DD形式）
                - start (str): 取得期間の開始日（YYYY-MM-DD形式）
                - total (float): 当月の月次集計の合計コスト（USD）


    Raises:
        ValueError: コスト取得期間が範囲外（1-30日）の場合
        Exception: Cost Explorer APIの呼び出しに失敗した場合
    """
    cost = {"budget": 0.0, "daily": {}, "monthly_this": {}, "monthly_last": {}}

    # コスト取得期間のチェック
    try:
        # EventBridgeからの設定値を取得（デフォルト$1）
        detail = (
            event.get("detail", {}) if isinstance(event.get("detail"), dict) else {}
        )

        cost["budget"] = float(detail.get("budget", 1))

        # 妥当性チェック（$1〜9999の範囲）
        if not (0 <= cost["budget"] <= 9999):
            raise ValueError(
                f"budget must be set in the range of 0-9999: {cost['budget']}"
            )
    except (ValueError, TypeError) as e:
        raise ValueError(f"Invalid value for budget: {cost['budget']}") from e

    # 月次予算金額のチェック
    try:
        # EventBridgeからの設定値を取得（デフォルト1日）
        detail = (
            event.get("detail", {}) if isinstance(event.get("detail"), dict) else {}
        )

        cost["daily"]["PeriodDays"] = int(detail.get("cost_period_days", 1))

        # 妥当性チェック（1日〜30日の範囲）
        if not (1 <= cost["daily"]["PeriodDays"] <= 30):
            raise ValueError(
                f"cost_period_days must be set in the range of 1-30: {cost['daily']['PeriodDays']}"
            )
    except (ValueError, TypeError) as e:
        raise ValueError(
            f"Invalid value for cost_period_days: {cost['daily']['PeriodDays']}"
        ) from e

    # 日次計算で使う日付
    today = date.today()
    cost["daily"]["end"] = today.strftime("%Y-%m-%d")
    day_start = today - timedelta(days=cost["daily"]["PeriodDays"])
    cost["daily"]["start"] = day_start.strftime("%Y-%m-%d")

    # 当月の月次計算で使う日付
    cost["monthly_this"]["PeriodDays"] = (today - today.replace(day=1)).days + 1
    cost["monthly_this"]["end"] = today.strftime("%Y-%m-%d")
    cost["monthly_this"]["start"] = today.replace(day=1).strftime("%Y-%m-%d")

    # 先月の月次計算で使う日付（日次取得が月跨ぎの時）
    last_end = today.replace(day=1) - timedelta(days=1)
    last_start = last_end.replace(day=1)
    if cost["daily"]["start"] < cost["monthly_this"]["start"]:
        cost["monthly_last"]["PeriodDays"] = (last_end - last_start).days + 1
        cost["monthly_last"]["end"] = last_end.strftime("%Y-%m-%d")
        cost["monthly_last"]["start"] = last_start.strftime("%Y-%m-%d")

    try:
        # Cost ExplorerはUS East 1固定（AWSの仕様）
        client = boto3.client("ce", region_name="us-east-1")

        # boto3で日次コストを取得
        daily_cost = client.get_cost_and_usage(
            TimePeriod={"Start": cost["daily"]["start"], "End": cost["daily"]["end"]},
            Granularity="DAILY",
            Metrics=["UnblendedCost"],
        )

        cost["daily"]["total"] = 0
        for result in daily_cost["ResultsByTime"]:
            amount = float(result["Total"]["UnblendedCost"]["Amount"])
            cost["daily"]["total"] += amount

        # boto3で当月の月次コストを取得
        monthly_this_cost = client.get_cost_and_usage(
            TimePeriod={
                "Start": cost["monthly_this"]["start"],
                "End": cost["monthly_this"]["end"],
            },
            Granularity="MONTHLY",
            Metrics=["UnblendedCost"],
        )

        cost["monthly_this"]["total"] = float(
            monthly_this_cost["ResultsByTime"][0]["Total"]["UnblendedCost"]["Amount"]
        )

        # boto3で先月の月次コストを取得（日次取得が月跨ぎの時）
        if cost["monthly_last"] != {}:
            monthly_last_cost = client.get_cost_and_usage(
                TimePeriod={
                    "Start": cost["monthly_last"]["start"],
                    "End": cost["monthly_last"]["end"],
                },
                Granularity="MONTHLY",
                Metrics=["UnblendedCost"],
            )

            cost["monthly_last"]["total"] = float(
                monthly_last_cost["ResultsByTime"][0]["Total"]["UnblendedCost"][
                    "Amount"
                ]
            )

        return cost

    except Exception as e:
        logger.error(f"Cost data retrieval error: {str(e)}")
        raise


def create_cost_embed(cost: Dict[str, Any]) -> Embed:
    """
    コスト通知用のDiscord Embedオブジェクトを作成する

    Args:
        cost: コスト情報の辞書
            - budget (float): 月次予算金額（USD）
            - daily: 日次集計
                - PeriodDays (int): コスト取得期間（日数）
                - end (str): 取得期間の終了日（YYYY-MM-DD形式）
                - start (str): 取得期間の開始日（YYYY-MM-DD形式）
                - total (float): 合計コスト（USD）
            - monthly_this: 当月の月次集計
                - PeriodDays (int): コスト取得期間（日数）
                - end (str): 取得期間の終了日（YYYY-MM-DD形式）
                - start (str): 取得期間の開始日（YYYY-MM-DD形式）
                - total (float): 当月の月次集計の合計コスト（USD）
            - monthly_last: 先月の月次集計
                - PeriodDays (int): コスト取得期間（日数）
                - end (str): 取得期間の終了日（YYYY-MM-DD形式）
                - start (str): 取得期間の開始日（YYYY-MM-DD形式）
                - total (float): 当月の月次集計の合計コスト（USD）

    Returns:
        discord.Embed: コスト通知用のEmbedオブジェクト
    """
    # 期間とメッセージテキストを作成
    main_text = f"**{cost['daily']['start'][5:].replace('-', '月')}日** から **{cost['daily']['end'][5:].replace('-', '月')}日** までのAWS利用料金をお知らせします 📊"

    # discord.pyのEmbedオブジェクトを作成
    embed = Embed(
        title="AWS料金通知 💰", description=main_text, color=0xFF9900  # オレンジ色
    )

    # 日次コストのフィールド追加
    embed.add_field(
        name="💸 料金$", value=f"$ {cost['daily']['total']:.2f}", inline=True
    )
    embed.add_field(
        name="📅 期間days", value=f"{cost['daily']['PeriodDays']} days", inline=True
    )

    # 当月の月次コストのフィールド追加
    monthly_this_rate = f"{math.ceil(cost['monthly_this']['total']) / math.ceil(cost['budget']) * 100:.1f}%"
    monthly_this_value = (
        f"$ {math.ceil(cost['monthly_this']['total'])} / $ {math.ceil(cost['budget'])}"
    )
    embed.add_field(
        name="💹当月料金$/予算$＝消化率% ($切り上げ)",
        value=f"{monthly_this_value} = {monthly_this_rate}",
        inline=False,
    )

    # 先月の月次コストのフィールド追加（日次取得が月跨ぎの時）
    if cost["monthly_last"] != {}:
        monthly_last_rate = f"{math.ceil(cost['monthly_last']['total']) / math.ceil(cost['budget']) * 100:.1f}%"
        monthly_last_value = f"$ {math.ceil(cost['monthly_last']['total'])} / $ {math.ceil(cost['budget'])}"
        embed.add_field(
            name="💹先月料金$/予算$＝消化率% ($切り上げ)",
            value=f"{monthly_last_value} = {monthly_last_rate}",
            inline=False,
        )

    # フッター設定
    embed.set_footer(
        text=f"{AWS_USERNAME} | Generated by Terraform ⚡",
        icon_url=AWS_AVATAR_URL,
    )

    logger.info("Discord embed created and validated successfully")
    return embed


async def post_to_discord(
    config: Dict[str, Any],
    message: Optional[str] = None,
    embed: Optional[Embed] = None,
) -> None:
    """
    aiohttp + discord.pyを使用してDiscordにメッセージを投稿する

    Args:
        config: Webhook設定値の辞書
            - webhook_url (str): Discord Webhook URL
            - webhook_username (str): Discordに表示されるユーザー名
            - webhook_avatar_url (str): Discordに表示されるアバター画像URL
        message: プレーンテキストメッセージ（オプション、embedがない場合に使用）
        embed: Discord Embedオブジェクト（オプション、優先して使用される）

    Raises:
        ValueError: messageとembedの両方がNoneの場合
        discord.HTTPException: Discord APIのHTTPエラー
        Exception: その他の予期しないエラー
    """
    try:
        async with aiohttp.ClientSession() as session:
            webhook = Webhook.from_url(config["webhook_url"], session=session)

            # メッセージ送信
            if embed:
                # Embedがある場合
                await webhook.send(
                    embed=embed,
                    username=config["webhook_username"],
                    avatar_url=config["webhook_avatar_url"],
                )
            elif message:
                # プレーンテキストメッセージの場合
                await webhook.send(
                    content=message,
                    username=config["webhook_username"],
                    avatar_url=config["webhook_avatar_url"],
                )
            else:
                # メッセージまたはEmbedのどちらかが必要
                raise ValueError("Either message or embed must be provided")

        logger.info("Discord notification sent successfully using aiohttp")

    except HTTPException as e:
        logger.error(f"Discord HTTP error: {e.status} - {e.text}")
        raise
    except Exception as e:
        logger.error(f"Unexpected error in Discord notification: {str(e)}")
        raise


def lambda_handler(event, context=None):
    """
    AWS Cost NotifierのLambda関数メインハンドラ

    EventBridgeからのスケジュール実行でAWSコストを取得し、Discordに通知する

    Args:
        event: EventBridgeから渡されるイベントデータ
            - detail.webhookUrl (str): Discord Webhook URL
            - detail.webhookUsername (str, optional): Discordユーザー名
            - detail.webhookAvatarUrl (str, optional): Discordアバター画像URL
            - detail.costday_PeriodDays (str, optional): コスト取得期間（デフォルト: 7日）
        context: Lambda実行コンテキスト

    Returns:
        dict: Lambda実行結果
            - statusCode (int): HTTPステータスコード（200: 成功、500: エラー）
            - body (str): JSON形式のレスポンスボディ

    Raises:
        ValueError: 設定値が無効な場合
        Exception: コスト取得またはDiscord通知に失敗した場合
    """
    try:
        # EventBridgeイベントから設定値を取得
        config = get_config_from_event(event)

        # Cost Explorerから料金を取得
        cost = get_cost(event)

        # コスト情報を表示するEmbedを作成
        embed = create_cost_embed(cost)

        # Discordに通知（Embedを使用）
        asyncio.run(post_to_discord(config=config, embed=embed))

        return {
            "statusCode": 200,
            "body": {
                "message": "Discord通知送信完了",
                "payload": {
                    "config": config,
                    "cost": cost,
                },
            },
        }

    except Exception as e:
        error_message = f"Lambda function error occurred: {str(e)}"
        logger.error(error_message)

        return {"statusCode": 500, "body": {"error": error_message}}


# テスト実行用
if __name__ == "__main__":
    # テスト実行時のモックイベント（EventBridge形式）
    # 実際のEventBridgeから渡されるイベント構造を模倣
    test_event = {
        "version": "0",
        "id": "test-event-id",
        "detail-type": "Scheduled Event",
        "source": "aws.events",
        "account": "123456789012",
        "time": "2024-01-01T09:00:00Z",
        "region": "us-east-1",
        "resources": [
            "arn:aws:events:us-east-1:123456789012:rule/aws-cost-notification-schedule-dev"
        ],
        # カスタム設定値をdetailセクションに含める
        "detail": {
            "webhookUrl": "https://discord.com/api/webhooks/test",
            "webhookUsername": "テスト用AWS料金通知ボット",
            "webhookAvatarUrl": "https://shared-handson.github.io/icons-factory/aws/Savings-Plans.png",
            "costday_PeriodDays": 10,
            "budget": 120,
        },
    }

    # Lambda context のモック
    test_context = type(
        "Context",
        (),
        {
            "function_name": "aws-cost-notifier-test",
            "function_version": "$LATEST",
            "invoked_function_arn": "arn:aws:lambda:us-east-1:123456789012:function:aws-cost-notifier-test",
            "memory_limit_in_mb": 256,
            "remaining_time_in_millis": lambda: 30000,
            "log_group_name": "/aws/lambda/aws-cost-notifier-test",
            "log_stream_name": "2024/01/01/[$LATEST]abcdefg1234567890",
            "aws_request_id": "test-request-id",
        },
    )()

    # Lambda関数を実行
    print("=== EventBridge形式でのLambda関数テスト実行 ===")
    print(
        f"イベント設定: webhookUsername={test_event['detail']['webhookUsername']}, costday_PeriodDays={test_event['detail']['costday_PeriodDays']}, budget={test_event['detail']['budget']}"
    )

    result = lambda_handler(test_event, test_context)
    print("\n=== 実行結果 ===")
    print(json.dumps(result, indent=2, ensure_ascii=False))
