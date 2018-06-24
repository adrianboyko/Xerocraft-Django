# Generated by Django 2.0.3 on 2018-06-16 01:00

from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('soda', '0001_initial'),
    ]

    operations = [
        migrations.AlterField(
            model_name='vendlog',
            name='who_for',
            field=models.ForeignKey(help_text='Who was this product vended for?', on_delete=django.db.models.deletion.PROTECT, to='members.Member'),
        ),
    ]