# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('members', '0008_visitevent_method'),
    ]

    operations = [
        migrations.AlterUniqueTogether(
            name='visitevent',
            unique_together=set([('who', 'when')]),
        ),
    ]
