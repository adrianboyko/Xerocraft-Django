# Generated by Django 2.0.3 on 2018-07-09 06:31

from django.db import migrations, models
import django.db.models.deletion
from kmkr.models import Show, ShowTime


def forward_func(apps, schema_editor):
    for s in Show.objects.all():
        ShowTime.objects.create(
        show=s,
        mondays=s.mondays,
        tuesdays=s.tuesdays,
        wednesdays=s.wednesdays,
        thursdays=s.thursdays,
        fridays=s.fridays,
        saturdays=s.saturdays,
        sundays=s.sundays,
        start_time=s.start_time,
        minute_duration=s.minute_duration)


class Migration(migrations.Migration):

    dependencies = [
        ('kmkr', '0008_auto_20180708_1255'),
    ]

    operations = [
        migrations.CreateModel(
            name='ShowTime',
            fields=[
                ('id', models.AutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('start_time', models.TimeField(help_text='The time at which the show begins.')),
                ('minute_duration', models.IntegerField(help_text='The duration of the show in MINUTES.')),
                ('first', models.BooleanField(default=False, verbose_name='1st')),
                ('second', models.BooleanField(default=False, verbose_name='2nd')),
                ('third', models.BooleanField(default=False, verbose_name='3rd')),
                ('fourth', models.BooleanField(default=False, verbose_name='4th')),
                ('every', models.BooleanField(default=True)),
                ('sundays', models.BooleanField(default=False, verbose_name='Sun')),
                ('mondays', models.BooleanField(default=False, verbose_name='Mon')),
                ('tuesdays', models.BooleanField(default=False, verbose_name='Tue')),
                ('wednesdays', models.BooleanField(default=False, verbose_name='Wed')),
                ('thursdays', models.BooleanField(default=False, verbose_name='Thu')),
                ('fridays', models.BooleanField(default=False, verbose_name='Fri')),
                ('saturdays', models.BooleanField(default=False, verbose_name='Sat')),
            ],
        ),
        migrations.AlterField(
            model_name='show',
            name='title',
            field=models.CharField(help_text='The name of this show.', max_length=80),
        ),
        migrations.AddField(
            model_name='showtime',
            name='show',
            field=models.ForeignKey(help_text='The show in question.', on_delete=django.db.models.deletion.CASCADE, to='kmkr.Show'),
        ),

        #migrations.RunPython(forward_func)

    ]
