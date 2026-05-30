from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('orders', '0013_add_fee_split_to_feepreset'),
    ]

    operations = [
        migrations.AddField(
            model_name='menuitem',
            name='image_url',
            field=models.URLField(blank=True, help_text='Item image URL from Talabat CDN', max_length=1000),
        ),
    ]
