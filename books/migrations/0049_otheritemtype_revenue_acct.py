# -*- coding: utf-8 -*-
# Generated by Django 1.9.10 on 2017-01-11 20:58
from __future__ import unicode_literals

from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('books', '0048_expenseclaim_journal_entry'),
    ]

    operations = [
        migrations.AddField(
            model_name='otheritemtype',
            name='revenue_acct',
            field=models.ForeignKey(blank=True, default=None, help_text='The revenue account associated with items of this type.', null=True, on_delete=django.db.models.deletion.PROTECT, to='books.Account'),
        ),
    ]
