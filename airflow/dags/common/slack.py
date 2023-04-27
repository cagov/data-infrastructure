from airflow.providers.slack.hooks.slack_webhook import SlackWebhookHook


def post_to_slack_on_failure(context):
    hook = SlackWebhookHook(
        slack_webhook_conn_id="caldata-dataservices-bot-notifications"
    )
    msg = f"""
        :x: Task Failed.
        *Task*: {context.get('task_instance').task_id}
        *Dag*: {context.get('task_instance').dag_id}
        *Execution Time*: {context.get('execution_date')}
        <{context.get('task_instance').log_url}|*Logs*>
    """
    hook.send_text(msg)
