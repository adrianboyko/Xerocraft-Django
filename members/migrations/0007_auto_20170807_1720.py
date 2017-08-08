# -*- coding: utf-8 -*-
# Generated by Django 1.10.6 on 2017-08-08 00:20
from __future__ import unicode_literals

from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('members', '0006_auto_20170807_1607'),
    ]

    operations = [
        migrations.AlterField(
            model_name='keyfee',
            name='sale',
            field=models.ForeignKey(default=None, help_text='The sale that includes this line item.', on_delete=django.db.models.deletion.CASCADE, to='books.Sale'),
            preserve_default=False,
        ),
    ]