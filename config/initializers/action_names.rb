Feedbin::Application.config.action_names = []
Feedbin::Application.config.action_names << ActionName.new(label: 'Mark it as Read', value: 'mark_read')
Feedbin::Application.config.action_names << ActionName.new(label: 'Star It', value: 'star')
Feedbin::Application.config.action_names << ActionName.new(label: 'Send Me Push Notification', value: 'send_push_notification')