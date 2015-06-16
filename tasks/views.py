from django.shortcuts import render
from django.http import HttpResponse
from django.template import loader
from tasks.models import Task

def index(request):
    template = loader.get_template('tasks/index.html')
    return HttpResponse(template.render(None))

def list(request):
    """ This view will present all tasks with status and optional filtering.
    """
    task_list = Task.objects.all()
    return render(request,'tasks/list.html',{'task_list': task_list})
