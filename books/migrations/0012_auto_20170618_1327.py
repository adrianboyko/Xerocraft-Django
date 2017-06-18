# -*- coding: utf-8 -*-
# Generated by Django 1.10.6 on 2017-06-18 20:27
from __future__ import unicode_literals

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('books', '0011_auto_20170617_2223'),
    ]

    operations = [
        migrations.AlterField(
            model_name='otheritem',
            name='qty_sold',
            field=models.IntegerField(blank=True, default=None, help_text='The quantity of the item sold. Leave blank if quantity is not known.', null=True),
        ),
    ]
