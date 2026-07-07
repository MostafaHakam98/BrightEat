# Generated for menu item modifiers/options feature

import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('orders', '0018_recurringorder'),
    ]

    operations = [
        migrations.CreateModel(
            name='MenuItemOptionGroup',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('name', models.CharField(max_length=100)),
                ('is_required', models.BooleanField(default=False)),
                ('min_select', models.PositiveIntegerField(default=0, help_text='Minimum options that must be chosen')),
                ('max_select', models.PositiveIntegerField(default=1, help_text='Maximum options that may be chosen (1 = single choice)')),
                ('display_order', models.PositiveIntegerField(default=0)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('menu_item', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='option_groups', to='orders.menuitem')),
            ],
            options={
                'ordering': ['display_order', 'id'],
            },
        ),
        migrations.CreateModel(
            name='MenuItemOption',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('name', models.CharField(max_length=100)),
                ('price_delta', models.DecimalField(decimal_places=2, default=0, max_digits=10)),
                ('is_default', models.BooleanField(default=False)),
                ('is_available', models.BooleanField(default=True)),
                ('display_order', models.PositiveIntegerField(default=0)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('group', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='options', to='orders.menuitemoptiongroup')),
            ],
            options={
                'ordering': ['display_order', 'id'],
            },
        ),
        migrations.AddField(
            model_name='orderitem',
            name='selected_options',
            field=models.JSONField(blank=True, default=list),
        ),
        migrations.AddField(
            model_name='orderitem',
            name='options_signature',
            field=models.CharField(blank=True, default='', max_length=64),
        ),
        migrations.AlterUniqueTogether(
            name='orderitem',
            unique_together={('order', 'user', 'menu_item', 'custom_name', 'options_signature')},
        ),
    ]
