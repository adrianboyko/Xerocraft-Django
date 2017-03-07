# -*- coding: utf-8 -*-
# Generated by Django 1.10.5 on 2017-01-24 18:36
from __future__ import unicode_literals

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('members', '0055_member_nag_re_membership'),
    ]

    operations = [
        migrations.AlterField(
            model_name='member',
            name='membership_card_md5',
            field=models.CharField(blank=True, help_text='MD5 of the member card#. Field will auto-apply MD5 if value is digits.', max_length=32, null=True),
        ),
    ]